const {chromium}=require('playwright');const fs=require('node:fs');const assert=require('node:assert/strict');const {pathToFileURL}=require('node:url');
(async()=>{const payload={nonce:'fictional-test',images:{0:'data:image/svg+xml;base64,'+Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="400" height="900"><rect width="400" height="900" fill="white"/></svg>').toString('base64')},cases:[{id:'fictional-case',slot:0,kind:'purchase',description:'OAT CRACKERS XYZ',amount:'',rows:[],reason:'Fictional duplicate row test'}]};
const file='/tmp/sliplet-p705-fictional.html';fs.writeFileSync(file,fs.readFileSync('evaluation/receipt-focused-audit/review.html','utf8').replace('__PAYLOAD__',JSON.stringify(payload)));
const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
try{const page=await browser.newPage({viewport:{width:1280,height:900}});let external=0;page.on('request',r=>{if(/^https?:/.test(r.url()))external++});
await page.goto(pathToFileURL(file).href);await page.waitForFunction(()=>document.querySelector('canvas').height===900);
assert.equal(await page.locator('#confirmed').isChecked(),false);assert.equal(await page.locator('#amount').inputValue(),'');
await page.locator('#export').click();assert.match(await page.locator('#message').textContent(),/still need checking/);
await page.locator('#confirmed').click();assert.equal(await page.locator('#confirmed').isChecked(),false);
const rect=await page.locator('canvas').boundingBox();async function mark(y){await page.mouse.move(rect.x+30,rect.y+y);await page.mouse.down();await page.mouse.move(rect.x+240,rect.y+y+25);await page.mouse.up()}
await mark(40);await page.locator('#amount').fill('6.00');await page.locator('#add').click();await page.locator('textarea[aria-label="Literal row 1"]').fill('OAT CRACKERS XYZ 6.00');await mark(40);
await page.locator('#confirmed').check();assert.equal(await page.locator('#confirmed').isChecked(),true);
const download=page.waitForEvent('download');await page.locator('#export').click();const d=await download;const exported=JSON.parse(fs.readFileSync(await d.path(),'utf8'));assert.equal(exported.complete,true);assert.equal(exported.cases[0].confirmed,true);assert.equal(exported.images,undefined);
await page.locator('#amount').fill('7.00');assert.equal(await page.locator('#confirmed').isChecked(),false);await page.reload();assert.equal(await page.locator('#amount').inputValue(),'7.00');assert.equal(await page.locator('#confirmed').isChecked(),false);assert.equal(external,0);
await page.goto(pathToFileURL(process.cwd()+'/private-receipts/evaluation/p7-05-review/review.html').href);await page.waitForFunction(()=>document.querySelector('canvas').height>150);assert.equal(await page.locator('#cases option').count(),23);assert.equal(await page.locator('#confirmed').isChecked(),false);assert.equal(external,0);
console.log('Browser checks passed: unconfirmed gating, region marking, export, edit invalidation, reload persistence, 23-case private page, zero network requests.');
}finally{await browser.close()}})().catch(()=>{console.error('Browser verification failed; no private content emitted.');process.exit(1)});
