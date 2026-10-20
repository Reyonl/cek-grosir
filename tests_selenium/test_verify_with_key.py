import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

def test_full_ocr_flow():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument('--headless=new')
    chrome_options.add_argument('--window-size=1280,950')
    driver = webdriver.Chrome(options=chrome_options)
    api_key = "AIzaSyDb42HWIHnsvQLlvRvm4LJiKDcORG_PfJk"

    try:
        driver.get('http://localhost:8089')
        time.sleep(3)

        # Enable accessibility
        placeholder = driver.find_elements(By.TAG_NAME, 'flt-semantics-placeholder')
        if placeholder:
            driver.execute_script("arguments[0].click();", placeholder[0])
            time.sleep(2)

        # 1. Atur API Key
        btn_key = driver.find_element(By.XPATH, "//*[contains(text(), 'Pengaturan API Key Gemini')]")
        driver.execute_script("arguments[0].click();", btn_key)
        time.sleep(1)

        inputs = driver.find_elements(By.XPATH, "//input")
        if inputs:
            inputs[0].clear()
            inputs[0].send_keys(api_key)
            time.sleep(1)

        save_btn = driver.find_element(By.XPATH, "//*[text()='Simpan']")
        driver.execute_script("arguments[0].click();", save_btn)
        time.sleep(1)

        # 2. Klik "Scan Bon"
        btn_scan = driver.find_element(By.XPATH, "//*[text()='Scan Bon']")
        driver.execute_script("arguments[0].click();", btn_scan)
        time.sleep(2)
        driver.save_screenshot("evidence/ocr_01_sheet_with_key.png")

        # 3. Verifikasi opsi bottom sheet
        host_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
        print("Visible options:\n", host_text)

        # 4. Klik "Coba Contoh Bon Grosir (Demo)"
        opt_demo = driver.find_element(By.XPATH, "//*[contains(text(), 'Coba Contoh Bon Grosir')]")
        driver.execute_script("arguments[0].click();", opt_demo)
        time.sleep(2)
        driver.save_screenshot("evidence/ocr_02_dialog_opened.png")
        print("[STEP] Opened ReceiptScanDialog.")

        # 5. Klik "Simpan Data Bon"
        btn_simpan_bon = driver.find_element(By.XPATH, "//*[text()='Simpan Data Bon']")
        driver.execute_script("arguments[0].click();", btn_simpan_bon)
        time.sleep(2)
        driver.save_screenshot("evidence/ocr_03_saved_to_cart.png")
        print("[STEP] Clicked 'Simpan Data Bon'.")

        # 6. Verifikasi item masuk ke keranjang
        final_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
        print("Final screen text:\n", final_text[:500])

        assert "Good Day Merah" in final_text or "Kopi ABC" in final_text, "Items should be added to cart!"
        print("[SUCCESS] Bon OCR workflow completely verified!")

    finally:
        driver.quit()

if __name__ == "__main__":
    test_full_ocr_flow()
