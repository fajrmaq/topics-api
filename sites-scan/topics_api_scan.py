# Run setup: pip install selenium pandas webdriver-manager

import json, time, pandas as pd
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import ChromiumOptions
from selenium.common.exceptions import TimeoutException
from webdriver_manager.chrome import ChromeDriverManager

# Config 
OUTPUT = "ScanResults.csv"
PAGE_TIMEOUT = 90      # how long to wait for a page
SKIP_AFTER = 120       # skip site if it takes longer
HEADLESS = True        # run without opening Chrome window 

# Website list to scan 
SITES = [
    ("https://www.nytimes.com", "News"),
    ("https://www.cnn.com", "News"),
    ("https://www.bbc.com", "News"),
    ("https://www.reuters.com", "News"),
    ("https://www.wsj.com", "News"),
    ("https://www.bloomberg.com", "News"),
    ("https://www.foxnews.com", "News"),
    ("https://www.theguardian.com", "News"),
    ("https://www.nbcnews.com", "News"),
    ("https://www.cbsnews.com", "News"),
    ("https://abcnews.go.com", "News"),
    ("https://www.usatoday.com", "News"),
    ("https://www.huffpost.com", "News"),
    ("https://www.theverge.com", "TechMedia"),
    ("https://www.techcrunch.com", "TechMedia"),
    ("https://www.youtube.com", "Video"),
    ("https://www.reddit.com", "Social"),
    ("https://www.amazon.com", "Ecommerce"),
    ("https://www.bestbuy.com", "Ecommerce"),
    ("https://www.walmart.com", "Ecommerce"),
    ("https://www.target.com", "Ecommerce"),
    ("https://www.ebay.com", "Ecommerce"),
    ("https://www.espn.com", "Sports"),
    ("https://www.cbssports.com", "Sports"),
    ("https://www.google.com", "Tech"),
    ("https://news.google.com", "Tech"),
    ("https://www.microsoft.com", "Tech"),
    ("https://www.apple.com", "Tech"),
    ("https://www.netflix.com", "Tech"),
]

# Ad platforms  
AD_DOMAINS = {
    "doubleclick.net": "Google Ads",
    "googlesyndication.com": "AdSense",
    "googletagservices.com": "Ad Manager",
    "pubmatic.com": "PubMatic",
    "criteo.com": "Criteo",
    "rubiconproject.com": "Magnite",
    "taboola.com": "Taboola",
    "outbrain.com": "Outbrain",
    "amazon-adsystem.com": "Amazon Ads",
}

# Create and setup Chrome driver 
def make_driver():
    opts = ChromiumOptions()
    if HEADLESS:
        opts.add_argument("--headless=new")
    opts.add_argument("--window-size=1920,1080")
    opts.add_argument("--enable-features=PrivacySandboxAdsAPIs,TopicsAPI")
    opts.page_load_strategy = "normal"
    opts.set_capability("goog:loggingPrefs", {"performance": "ALL"})
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=opts)
    driver.set_page_load_timeout(PAGE_TIMEOUT)
    return driver

# Interpret what document.browsingTopics() returns 
def classify(result):
    s = str(result)
    if "Permissions Policy" in s:
        return "BLOCKED", s[:100]
    if "not a function" in s or "not defined" in s:
        return "NOT_AVAILABLE", s[:100]
    if s.startswith("["):
        return "OK", s[:200]
    return "ERROR", s[:100]

# Check Chrome logs to find which ad platforms loaded 
def find_ads(logs):
    found = set()
    for entry in logs:
        try:
            msg = json.loads(entry["message"])["message"]
            if msg.get("method") != "Network.requestWillBeSent":
                continue
            url = msg["params"]["request"]["url"]
            for key, val in AD_DOMAINS.items():
                if key in url:
                    found.add(val)
        except:
            pass
    return "; ".join(sorted(found))

# Main scanning logic 
def main():
    driver = make_driver()
    results = []

    for url, cat in SITES:
        print(f"\n Scanning {url}")
        start = time.time()
        status, info, ads = "ERROR", "", ""

        try:
            driver.get(url)
            if time.time() - start > SKIP_AFTER:
                print("Too slow, skipping.")
                continue
            time.sleep(6)

            js = """
            return (async () => {
              try { return await document.browsingTopics(); }
              catch(e){ return e.toString(); }
            })();
            """
            res = driver.execute_script(js)
            status, info = classify(res)
            ads = find_ads(driver.get_log("performance"))

        except TimeoutException:
            print("Timeout, skipping.")
        except Exception as e:
            info = str(e)[:100]

        results.append({
            "website": url,
            "category": cat,
            "topics_status": status,
            "details": info,
            "ad_platforms": ads
        })

        pd.DataFrame(results).to_csv(OUTPUT, index=False)
        print(f"{status} ({round(time.time()-start,1)}s)")

    driver.quit()
    print("\n Scan complete! Results saved to", OUTPUT)

if __name__ == "__main__":
    main()
