// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static androidx.media3.common.Player.REPEAT_MODE_ALL;
import static androidx.media3.common.Player.REPEAT_MODE_OFF;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.TrackGroup;
import androidx.media3.common.TrackSelectionOverride;
import androidx.media3.common.Tracks;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import io.flutter.view.TextureRegistry.SurfaceProducer;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.exoplayer.hls.HlsMediaSource;
import androidx.media3.exoplayer.source.ProgressiveMediaSource;
import androidx.media3.exoplayer.source.MediaSource;

/**
 * A class responsible for managing video playback using {@link ExoPlayer}.
 *
 * <p>It provides methods to control playback, adjust volume, and handle seeking.
 */
public abstract class VideoPlayer implements VideoPlayerInstanceApi {
  @NonNull protected final VideoPlayerCallbacks videoPlayerEvents;
  @Nullable protected final SurfaceProducer surfaceProducer;
  @Nullable private DisposeHandler disposeHandler;
  @NonNull protected ExoPlayer exoPlayer;
  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi @Nullable protected DefaultTrackSelector trackSelector;

  /** A closure-compatible signature since {@link java.util.function.Supplier} is API level 24. */
  public interface ExoPlayerProvider {
    /**
     * Returns a new {@link ExoPlayer}.
     *
     * @return new instance.
     */
    @NonNull
    ExoPlayer get();
  }

  /** A handler to run when dispose is called. */
  public interface DisposeHandler {
    void onDispose();
  }

  @Nullable protected Context context;

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  // Error thrown for this-escape warning on JDK 21+ due to
  // https://bugs.openjdk.org/browse/JDK-8015831.
  // Keeping behavior as-is and addressing the warning could cause a regression:
  // https://github.com/flutter/packages/pull/10193
  @SuppressWarnings("this-escape")
  public VideoPlayer(
      @NonNull VideoPlayerCallbacks events,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @Nullable SurfaceProducer surfaceProducer,
      @NonNull ExoPlayerProvider exoPlayerProvider) {
    this(null, events, mediaItem, options, surfaceProducer, exoPlayerProvider);
  }

  @UnstableApi
  @SuppressWarnings("this-escape")
  public VideoPlayer(
      @Nullable Context context,
      @NonNull VideoPlayerCallbacks events,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @Nullable SurfaceProducer surfaceProducer,
      @NonNull ExoPlayerProvider exoPlayerProvider) {
    this.context = context;
    this.videoPlayerEvents = events;
    this.surfaceProducer = surfaceProducer;
    exoPlayer = exoPlayerProvider.get();

    // Try to get the track selector from the ExoPlayer if it was built with one
    if (exoPlayer.getTrackSelector() instanceof DefaultTrackSelector) {
      trackSelector = (DefaultTrackSelector) exoPlayer.getTrackSelector();
    }

    exoPlayer.addListener(createExoPlayerEventListener(exoPlayer, surfaceProducer));

    // 8. Add complete error logging.
    exoPlayer.addListener(new androidx.media3.common.Player.Listener() {
      @Override
      public void onPlayerError(@NonNull androidx.media3.common.PlaybackException error) {
        android.util.Log.e("Player", "ErrorCode=" + androidx.media3.common.PlaybackException.getErrorCodeName(error.errorCode), error);
      }
    });

    setAudioAttributes(exoPlayer, options.mixWithOthers);

    // Verify URL accessibility and content-type detection
    if (mediaItem.localConfiguration != null && mediaItem.localConfiguration.uri != null &&
        (mediaItem.localConfiguration.uri.getScheme().equalsIgnoreCase("http") ||
         mediaItem.localConfiguration.uri.getScheme().equalsIgnoreCase("https"))) {
      verifyAndPrepareHttpPlayback(mediaItem, options);
    } else {
      exoPlayer.setMediaItem(mediaItem);
      exoPlayer.prepare();
    }
  }

  @OptIn(markerClass = UnstableApi.class)
  private void verifyAndPrepareHttpPlayback(@NonNull final MediaItem mediaItem, @NonNull final VideoPlayerOptions options) {
    final String mediaId = mediaItem.mediaId;
    final String urlString = mediaItem.localConfiguration.uri.toString();

    new Thread(new Runnable() {
      @Override
      public void run() {
        // 1. Log final URL before playback.
        Log.d("Player", "Final URL before playback: " + urlString);

        HttpURLConnection connection = null;
        try {
          // Retrieve custom headers / user-agent from static registry
          Map<String, String> originalHeaders = null;
          String userAgentStr = null;
          HttpVideoAsset activeAsset = HttpVideoAsset.getActiveAsset(mediaId != null ? mediaId : urlString);
          if (activeAsset != null) {
            originalHeaders = activeAsset.getHttpHeaders();
            userAgentStr = activeAsset.getUserAgent();
          }

          final Map<String, String> resolvedHeaders = new HashMap<>();
          if (originalHeaders != null) {
            resolvedHeaders.putAll(originalHeaders);
          }

          // 5. Add default HTTP headers if missing, or force them if it's a MovieBox stream.
          boolean isMovieBox = urlString.contains("hakunaymatata.com") || 
                              urlString.contains("aoneroom.com") || 
                              urlString.contains("movieboxpro.app");

          if (isMovieBox) {
            resolvedHeaders.put("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36");
            resolvedHeaders.put("Referer", "https://fmoviesunblocked.net/");
            resolvedHeaders.put("Origin", "https://h5.aoneroom.com");
            resolvedHeaders.put("Accept", "*/*");
          } else {
            if (!resolvedHeaders.containsKey("User-Agent")) {
              resolvedHeaders.put("User-Agent", "Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36");
            }
            if (!resolvedHeaders.containsKey("Referer")) {
              resolvedHeaders.put("Referer", "https://www.movieboxpro.app/");
            }
            if (!resolvedHeaders.containsKey("Origin")) {
              resolvedHeaders.put("Origin", "https://www.movieboxpro.app");
            }
            if (!resolvedHeaders.containsKey("Accept")) {
              resolvedHeaders.put("Accept", "*/*");
            }
          }

          final String finalUserAgent = resolvedHeaders.get("User-Agent");

          // 2. Perform HEAD request to verify URL accessibility.
          URL url = new URL(urlString);
          connection = (HttpURLConnection) url.openConnection();
          connection.setRequestMethod("HEAD");
          connection.setInstanceFollowRedirects(true);
          connection.setConnectTimeout(15000);
          connection.setReadTimeout(15000);

          for (Map.Entry<String, String> entry : resolvedHeaders.entrySet()) {
            connection.setRequestProperty(entry.getKey(), entry.getValue());
          }

          int responseCode = connection.getResponseCode();
          String contentType = connection.getContentType();
          int contentLength = connection.getContentLength();
          String finalUrl = connection.getURL().toString();

          // 10. Log all response/redirect properties.
          Log.d("Player", "URL: " + urlString);
          Log.d("Player", "contentType: " + contentType);
          Log.d("Player", "responseCode: " + responseCode);
          Log.d("Player", "headers: " + resolvedHeaders);
          Log.d("Player", "final redirected URL: " + finalUrl);

          // 3. If response code != 200 log exact error.
          if (responseCode < 200 || responseCode >= 300) {
            Log.e("Player", "HEAD request failed. Response Code: " + responseCode + ", Message: " + connection.getResponseMessage());
            
            // 9. If server returns 403 or 401, inspect required headers/cookies.
            if (responseCode == 401 || responseCode == 403) {
              Log.e("Player", "Auth error. Request headers sent: " + resolvedHeaders);
              Map<String, List<String>> responseHeaders = connection.getHeaderFields();
              Log.e("Player", "Response headers: " + responseHeaders);
            }
            
            notifyErrorOnMainThread("VideoError", "Server returned response code " + responseCode, null);
            return;
          }

          // 4. Detect/Validate content type. Reject text/html, application/json.
          if (contentType != null) {
            String ctLower = contentType.toLowerCase();
            if (ctLower.contains("text/html") || ctLower.contains("application/json")) {
              Log.e("Player", "Rejected Content-Type: " + contentType);
              notifyErrorOnMainThread("VideoError", "Unsupported content type: " + contentType, null);
              return;
            }
          }

          // 6. Create ExoPlayer MediaSource properly. Detect format automatically.
          boolean isHls = false;
          if (contentType != null) {
            String ctLower = contentType.toLowerCase();
            if (ctLower.contains("application/x-mpegurl") || 
                ctLower.contains("application/vnd.apple.mpegurl") || 
                ctLower.contains("mpegurl")) {
              isHls = true;
            }
          }
          if (!isHls) {
            String urlLower = finalUrl.toLowerCase();
            if (urlLower.contains(".m3u8")) {
              isHls = true;
            }
          }

          final boolean finalIsHls = isHls;
          final String finalPlayUrl = finalUrl;

          new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
              try {
                // 7. Enable redirects
                DefaultHttpDataSource.Factory httpDataSourceFactory = new DefaultHttpDataSource.Factory()
                    .setUserAgent(finalUserAgent)
                    .setAllowCrossProtocolRedirects(true);
                
                if (!resolvedHeaders.isEmpty()) {
                  httpDataSourceFactory.setDefaultRequestProperties(resolvedHeaders);
                }

                // Construct MediaSource depending on type
                androidx.media3.datasource.DataSource.Factory dataSourceFactory = (context != null)
                    ? new DefaultDataSource.Factory(context, httpDataSourceFactory)
                    : httpDataSourceFactory;

                MediaSource mediaSource;
                MediaItem playMediaItem = new MediaItem.Builder().setUri(finalPlayUrl).build();
                if (finalIsHls) {
                  Log.d("Player", "Creating HlsMediaSource for URL: " + finalPlayUrl);
                  mediaSource = new HlsMediaSource.Factory(dataSourceFactory).createMediaSource(playMediaItem);
                } else {
                  Log.d("Player", "Creating ProgressiveMediaSource for URL: " + finalPlayUrl);
                  mediaSource = new ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(playMediaItem);
                }

                exoPlayer.setMediaSource(mediaSource);
                exoPlayer.prepare();
              } catch (Exception e) {
                Log.e("Player", "Error preparing ExoPlayer MediaSource: " + e.getMessage(), e);
                videoPlayerEvents.onError("VideoError", e.getMessage(), null);
              }
            }
          });

        } catch (final Exception e) {
          Log.e("Player", "Error in HEAD verification: " + e.getMessage(), e);
          notifyErrorOnMainThread("VideoError", e.getMessage(), null);
        } finally {
          if (connection != null) {
            connection.disconnect();
          }
        }
      }
    }).start();
  }

  private void notifyErrorOnMainThread(final String code, final String message, final Object details) {
    new Handler(Looper.getMainLooper()).post(new Runnable() {
      @Override
      public void run() {
        videoPlayerEvents.onError(code, message, details);
      }
    });
  }

  public void setDisposeHandler(@Nullable DisposeHandler handler) {
    disposeHandler = handler;
  }

  @NonNull
  protected abstract ExoPlayerEventListener createExoPlayerEventListener(
      @NonNull ExoPlayer exoPlayer, @Nullable SurfaceProducer surfaceProducer);

  private static void setAudioAttributes(ExoPlayer exoPlayer, boolean isMixMode) {
    exoPlayer.setAudioAttributes(
        new AudioAttributes.Builder().setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
        !isMixMode);
  }

  @Override
  public void play() {
    exoPlayer.play();
  }

  @Override
  public void pause() {
    exoPlayer.pause();
  }

  @Override
  public void setLooping(boolean looping) {
    exoPlayer.setRepeatMode(looping ? REPEAT_MODE_ALL : REPEAT_MODE_OFF);
  }

  @Override
  public void setVolume(double volume) {
    float bracketedValue = (float) Math.max(0.0, Math.min(1.0, volume));
    exoPlayer.setVolume(bracketedValue);
  }

  @Override
  public void setPlaybackSpeed(double speed) {
    // We do not need to consider pitch and skipSilence for now as we do not handle them and
    // therefore never diverge from the default values.
    final PlaybackParameters playbackParameters = new PlaybackParameters((float) speed);

    exoPlayer.setPlaybackParameters(playbackParameters);
  }

  @Override
  public long getCurrentPosition() {
    return exoPlayer.getCurrentPosition();
  }

  @Override
  public long getBufferedPosition() {
    return exoPlayer.getBufferedPosition();
  }

  @Override
  public void seekTo(long position) {
    exoPlayer.seekTo(position);
  }

  @NonNull
  public ExoPlayer getExoPlayer() {
    return exoPlayer;
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @Override
  public @NonNull NativeAudioTrackData getAudioTracks() {
    List<ExoPlayerAudioTrackData> audioTracks = new ArrayList<>();

    // Get the current tracks from ExoPlayer
    Tracks tracks = exoPlayer.getCurrentTracks();

    // Iterate through all track groups
    for (int groupIndex = 0; groupIndex < tracks.getGroups().size(); groupIndex++) {
      Tracks.Group group = tracks.getGroups().get(groupIndex);

      // Only process audio tracks
      if (group.getType() == C.TRACK_TYPE_AUDIO) {
        for (int trackIndex = 0; trackIndex < group.length; trackIndex++) {
          Format format = group.getTrackFormat(trackIndex);
          boolean isSelected = group.isTrackSelected(trackIndex);

          // Create audio track data with metadata
          ExoPlayerAudioTrackData audioTrack =
              new ExoPlayerAudioTrackData(
                  (long) groupIndex,
                  (long) trackIndex,
                  format.label,
                  format.language,
                  isSelected,
                  format.bitrate != Format.NO_VALUE ? (long) format.bitrate : null,
                  format.sampleRate != Format.NO_VALUE ? (long) format.sampleRate : null,
                  format.channelCount != Format.NO_VALUE ? (long) format.channelCount : null,
                  format.codecs != null ? format.codecs : null);

          audioTracks.add(audioTrack);
        }
      }
    }
    return new NativeAudioTrackData(audioTracks);
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @Override
  public void selectAudioTrack(long groupIndex, long trackIndex) {
    if (trackSelector == null) {
      throw new IllegalStateException("Cannot select audio track: track selector is null");
    }

    // Get current tracks
    Tracks tracks = exoPlayer.getCurrentTracks();

    if (groupIndex < 0 || groupIndex >= tracks.getGroups().size()) {
      throw new IllegalArgumentException(
          "Cannot select audio track: groupIndex "
              + groupIndex
              + " is out of bounds (available groups: "
              + tracks.getGroups().size()
              + ")");
    }

    Tracks.Group group = tracks.getGroups().get((int) groupIndex);

    // Verify it's an audio track
    if (group.getType() != C.TRACK_TYPE_AUDIO) {
      throw new IllegalArgumentException(
          "Cannot select audio track: group at index "
              + groupIndex
              + " is not an audio track (type: "
              + group.getType()
              + ")");
    }

    // Verify the track index is valid
    if (trackIndex < 0 || (int) trackIndex >= group.length) {
      throw new IllegalArgumentException(
          "Cannot select audio track: trackIndex "
              + trackIndex
              + " is out of bounds (available tracks in group: "
              + group.length
              + ")");
    }

    // Get the track group and create a selection override
    TrackGroup trackGroup = group.getMediaTrackGroup();
    TrackSelectionOverride override = new TrackSelectionOverride(trackGroup, (int) trackIndex);

    // Apply the track selection override
    trackSelector.setParameters(
        trackSelector.buildUponParameters().setOverrideForType(override).build());
  }

  public void dispose() {
    if (disposeHandler != null) {
      disposeHandler.onDispose();
    }
    try {
      if (exoPlayer.getCurrentMediaItem() != null && exoPlayer.getCurrentMediaItem().mediaId != null) {
        HttpVideoAsset.removeActiveAsset(exoPlayer.getCurrentMediaItem().mediaId);
      }
    } catch (Exception ignored) {}
    exoPlayer.release();
  }
}
