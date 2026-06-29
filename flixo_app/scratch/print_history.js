/**
 * Extract history / search history / watch history from shared_preferences.json
 */
const fs = require('fs');

const path = 'C:\\Users\\Hp\\AppData\\Roaming\\com.example\\flixo_app\\shared_preferences.json';
const content = fs.readFileSync(path, 'utf8');
const data = JSON.parse(content);

console.log('Available keys:');
Object.keys(data).forEach(k => {
  console.log(`- ${k}: ${typeof data[k] === 'string' ? data[k].substring(0, 100) : JSON.stringify(data[k]).substring(0, 100)}`);
});

// Check history specifically
const historyKey = 'flutter.history';
if (data[historyKey]) {
  try {
    const list = JSON.parse(data[historyKey]);
    console.log('\n--- Watch History ---');
    list.forEach((m, i) => console.log(`[${i+1}] ID: ${m.id}, Title: ${m.title}`));
  } catch (e) {
    console.log('History parse error:', e.message);
  }
}
