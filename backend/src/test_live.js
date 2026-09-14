import { extractYouTube } from './extractors/youtube.js';
import { extractInstagram } from './extractors/instagram.js';
import { extractFacebook } from './extractors/facebook.js';
import { extractTikTok } from './extractors/tiktok.js';

async function testAll() {
  console.log('=== TESTING BACKEND EXTRACTORS FOR YOUTUBE, INSTAGRAM, FACEBOOK, TIKTOK ===\n');

  const tests = [
    { name: 'TikTok', fn: () => extractTikTok('https://www.tiktok.com/@scout2015/video/6718335390845095173') },
    { name: 'YouTube', fn: () => extractYouTube('https://www.youtube.com/watch?v=dQw4w9WgXcQ') },
    { name: 'Instagram', fn: () => extractInstagram('https://www.instagram.com/reel/C_Y0zGINR-Y/') },
    { name: 'Facebook', fn: () => extractFacebook('https://www.facebook.com/watch/?v=10153231379946729') }
  ];

  for (const t of tests) {
    try {
      console.log(`Testing ${t.name}...`);
      const res = await t.fn();
      console.log(`✅ SUCCESS [${t.name}]:`);
      console.log(`   Title: ${res.title}`);
      console.log(`   Formats Count: ${res.formats ? res.formats.length : 0}`);
      if (res.formats && res.formats.length > 0) {
        const url = res.formats[0].url;
        console.log(`   First Stream URL: ${url.slice(0, 80)}...`);
        const isWebpage = url.includes('youtube.com/watch') || url.includes('facebook.com') || url.includes('instagram.com/reel');
        if (isWebpage) {
          console.error(`❌ FAILURE: ${t.name} stream URL is a webpage link!`);
        } else {
          console.log(`   Stream Type: VALID DIRECT STREAM`);
        }
      }
    } catch (e) {
      console.error(`❌ ERROR [${t.name}]: ${e.message}`);
    }
    console.log('');
  }
}

testAll();
