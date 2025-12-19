const puppeteer = require('puppeteer');

async function fetchPage(layoutId, pageNumber) {
  const url = `https://qul.tarteel.ai/resources/mushaf-layout/${layoutId}?page=${pageNumber}`;
  
  console.error(`Fetching with Puppeteer: ${url}`);
  
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-web-security',
      '--disable-features=IsolateOrigins,site-per-process'
    ],
    ignoreHTTPSErrors: true
  });
  
  let page;
  try {
    page = await browser.newPage();
    
    // Handle page errors
    page.on('error', (error) => {
      console.error(`Page error: ${error.message}`);
    });
    
    page.on('pageerror', (error) => {
      console.error(`Page JavaScript error: ${error.message}`);
    });
    
    await page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    
    // Navigate to the page with retry logic and longer timeouts
    let navigationSuccess = false;
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        await page.goto(url, { 
          waitUntil: 'networkidle0', 
          timeout: 60000
        });
        console.error('Page loaded successfully');
        navigationSuccess = true;
        break;
      } catch (error) {
        console.error(`Navigation attempt ${attempt + 1} failed: ${error.message}`);
        if (attempt < 4) {
          await page.waitForTimeout(2000 * (attempt + 1)); // Exponential backoff
        } else {
          // Last attempt, try with a simpler wait condition
          try {
            await page.goto(url, { waitUntil: 'load', timeout: 40000 });
            console.error('Page loaded with load event');
            navigationSuccess = true;
          } catch (e2) {
            console.error(`Final navigation attempt failed: ${e2.message}`);
          }
        }
      }
    }
    
    if (!navigationSuccess) {
      throw new Error('Failed to navigate to page after all attempts');
    }
    
    // Wait a bit for JavaScript to execute
    await page.waitForTimeout(2000);
    
    // Wait for the preview container
    try {
      await page.waitForSelector('#run-preview', { timeout: 5000 });
      console.error('Found #run-preview container');
    } catch (e) {
      console.error('Warning: #run-preview not found, but continuing...');
    }
    
    // Wait for pageData to be populated
    let pageDataLength = 0;
    for (let i = 0; i < 20; i++) {
      try {
        pageDataLength = await page.evaluate(() => {
          return typeof pageData !== 'undefined' && pageData ? pageData.length : 0;
        });
        
        if (pageDataLength > 0) {
          console.error(`pageData loaded with ${pageDataLength} items`);
          break;
        }
      } catch (e) {
        // Ignore evaluation errors
      }
      
      await page.waitForTimeout(500);
    }
    
    // Wait for line elements to appear
    try {
      await page.waitForSelector('#run-preview div.line, #run-preview div.ayah', { timeout: 8000 });
      console.error('Line elements detected');
    } catch (e) {
      console.error('Warning: Line elements not found, but will try to extract from HTML...');
    }
    
    // Final wait to ensure rendering is complete
    await page.waitForTimeout(1500);
    
    // Try to extract pageData and wordData directly from JavaScript
    const jsData = await page.evaluate(() => {
      if (typeof pageData !== 'undefined' && pageData && typeof wordData !== 'undefined' && wordData) {
        return {
          pageData: pageData,
          wordData: wordData
        };
      }
      return null;
    });
    
    // Get the HTML content
    const htmlContent = await page.content();
    
    // Get line count
    const lineCount = await page.evaluate(() => {
      return document.querySelectorAll('#run-preview div.line, #run-preview div.ayah').length;
    });
    console.error(`Found ${lineCount} line elements in DOM`);
    
    // Return JSON with both HTML and JavaScript data
    const result = {
      html: htmlContent,
      lineCount: lineCount,
      pageData: jsData ? jsData.pageData : null,
      wordData: jsData ? jsData.wordData : null
    };
    
    console.log(JSON.stringify(result));
    
    await page.close();
    await browser.close();
  } catch (error) {
    console.error(`Error: ${error.message}`);
    if (page) {
      try {
        await page.close();
      } catch (e) {
        // Ignore
      }
    }
    try {
      await browser.close();
    } catch (e) {
      // Ignore
    }
    process.exit(1);
  }
}

// Get layout ID and page number from command line arguments
// Usage: node fetch_page.js <layoutId> <pageNumber>
// If only one argument is provided, assume it's pageNumber and use layout 313 (backward compatibility)
const layoutId = process.argv[3] ? process.argv[2] : '313';
const pageNumber = process.argv[3] || process.argv[2] || '4';

if (!layoutId || !pageNumber) {
  console.error(JSON.stringify({ error: 'Layout ID and page number required' }));
  process.exit(1);
}

fetchPage(layoutId, parseInt(pageNumber)).catch((error) => {
  console.error(JSON.stringify({ error: error.message }));
  process.exit(1);
});

