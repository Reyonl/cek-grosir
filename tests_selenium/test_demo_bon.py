import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

def test_demo_bon():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument('--headless=new')
    chrome_options.add_argument('--window-size=1280,950')
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get('http://localhost:8089')
        time.sleep(3)

        placeholder = driver.find_element(By.TAG_NAME, 'flt-semantics-placeholder')
        driver.execute_script("arguments[0].click();", placeholder)
        time.sleep(2)

        # 1. Click "Scan Bon"
        btn_scan = driver.find_element(By.XPATH, "//*[text()='Scan Bon']")
        driver.execute_script("arguments[0].click();", btn_scan)
        time.sleep(2)

        # 2. Click "Coba Contoh Bon Grosir (Demo)"
        opt_demo = driver.find_elements(By.XPATH, "//*[contains(text(), 'Coba Contoh Bon Grosir')]")
        print("Demo options found:", len(opt_demo))
        if opt_demo:
            driver.execute_script("arguments[0].click();", opt_demo[0])
            time.sleep(2)
            driver.save_screenshot("evidence/bug_scan_03_demo_dialog.png")
            print("[STEP] Clicked demo receipt.")

        # Check visible text
        host_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
        print("Visible text snippet after demo click:\n", host_text[:400])

    finally:
        driver.quit()

if __name__ == "__main__":
    test_demo_bon()
