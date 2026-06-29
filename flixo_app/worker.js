export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight (OPTIONS) requests directly
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS, PUT, DELETE",
          "Access-Control-Allow-Headers": "*",
          "Access-Control-Max-Age": "86400",
        }
      });
    }

    const url = new URL(request.url);
    const targetUrl = url.searchParams.get("url");

    if (!targetUrl) {
      return new Response("Missing target 'url' parameter", { 
        status: 400,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    }


    try {
      const parsedTarget = new URL(targetUrl);
      const headers = new Headers();
      
      // Copy over essential authorization headers if they exist
      if (request.headers.has("Authorization")) {
        headers.set("Authorization", request.headers.get("Authorization"));
      }
      if (request.headers.has("X-Client-Info")) {
        headers.set("X-Client-Info", request.headers.get("X-Client-Info"));
      }
      if (request.headers.has("Content-Type")) {
        headers.set("Content-Type", request.headers.get("Content-Type"));
      }
      if (request.headers.has("Range")) {
        headers.set("Range", request.headers.get("Range"));
      }
      
      headers.set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36");
      headers.set("Accept", "*/*");
      
      if (parsedTarget.hostname.includes("aoneroom.com") || parsedTarget.hostname.includes("hakunaymatata.com")) {
        headers.set("Referer", "https://h5.aoneroom.com/");
        headers.set("Origin", "https://h5.aoneroom.com");
      } else {
        headers.delete("Referer");
        headers.delete("Origin");
      }

      const targetResponse = await fetch(targetUrl, {
        method: request.method,
        headers: headers,
        cf: {
          cacheEverything: true,
          cacheTtl: 86400
        },
        body: request.method !== "GET" && request.method !== "HEAD" ? await request.text() : undefined
      });

      const responseHeaders = new Headers(targetResponse.headers);
      responseHeaders.set("Access-Control-Allow-Origin", "*");
      responseHeaders.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE");
      responseHeaders.set("Access-Control-Allow-Headers", "*");

      return new Response(targetResponse.body, {
        status: targetResponse.status,
        statusText: targetResponse.statusText,
        headers: responseHeaders
      });
    } catch (e) {
      return new Response("Proxy Error: " + e.message, { 
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};
