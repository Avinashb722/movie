/**
 * Debug script to resolve The Batman and KD - The Devil streams
 */
const { resolve } = require('path');
const TwoEmbedService = require('./decrypt_vidnest.js');

async function testMovie(imdbId, name) {
  console.log(`\n========================================`);
  console.log(`Testing ${name} (IMDb: ${imdbId})`);
  console.log(`========================================`);

  // We can execute the logic in decrypt_vidnest.js
  const exec = require('child_process').execSync;
  try {
    const output = exec(`node scratch/decrypt_vidnest.js ${imdbId}`).toString();
    console.log(output);
  } catch (e) {
    console.log(`Error running decryptor for ${imdbId}:`, e.message);
  }
}

async function main() {
  // The Batman (2022): tt1877830
  await testMovie('tt1877830', 'The Batman');

  // KD - The Devil: tt23851508
  await testMovie('tt23851508', 'KD - The Devil');
}

main();
