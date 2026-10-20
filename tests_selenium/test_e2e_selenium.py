import time
import os
import json
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options

def run_e2e():
    os.makedirs("evidence", exist_ok=True)
    chrome_options = Options()
    chrome_options.add_argument('--headless=new')
    chrome_options.add_argument('--window-size=1280,950')
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument('--disable-dev-shm-usage')
    chrome_options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})

    driver = webdriver.Chrome(options=chrome_options)
    api_key = "AIzaSyDb42HWIHnsvQLlvRvm4LJiKDcORG_PfJk"

    results = []

    try:
        # Step 1: Buka Web App
        driver.get('http://localhost:8089')
        time.sleep(3)

        # Enable Accessibility Tree
        placeholder = driver.find_element(By.TAG_NAME, 'flt-semantics-placeholder')
        driver.execute_script("arguments[0].click();", placeholder)
        time.sleep(2)

        driver.save_screenshot("evidence/e2e_01_loaded.png")
        print("[TC-01] Loaded Home Screen successfully.")

        # Step 2: Atur API Key via Dialog
        btn_key = driver.find_element(By.XPATH, "//*[contains(text(), 'Pengaturan API Key Gemini')]")
        driver.execute_script("arguments[0].click();", btn_key)
        time.sleep(2)

        driver.save_screenshot("evidence/e2e_02_api_key_dialog.png")
        print("[TC-02] Opened API Key Dialog.")

        # Temukan input API key di dialog
        inputs = driver.find_elements(By.XPATH, "//input")
        print(f"Inputs found in dialog: {len(inputs)}")
        if inputs:
            api_input = inputs[0]
            api_input.clear()
            api_input.send_keys(api_key)
            time.sleep(1)

        # Klik Simpan
        save_btn = driver.find_element(By.XPATH, "//*[text()='Simpan']")
        driver.execute_script("arguments[0].click();", save_btn)
        time.sleep(2)
        driver.save_screenshot("evidence/e2e_03_saved_key.png")
        print("[TC-03] Saved API Key.")

        # Step 3: Klik 'Isi Contoh'
        btn_isi_contoh = driver.find_element(By.XPATH, "//*[text()='Isi Contoh']")
        driver.execute_script("arguments[0].click();", btn_isi_contoh)
        time.sleep(1)
        driver.save_screenshot("evidence/e2e_04_isi_contoh.png")
        print("[TC-04] Clicked 'Isi Contoh'.")

        # Step 4: Klik 'Hitung Harga Grosir'
        btn_hitung = driver.find_element(By.XPATH, "//*[text()='Hitung Harga Grosir']")
        driver.execute_script("arguments[0].click();", btn_hitung)
        print("[TC-05] Triggered 'Hitung Harga Grosir', waiting for AI response...")

        # Tunggu sampai tombol loading 'Menghitung & Mencocokkan Harga...' selesai dan item muncul
        ai_success = False
        print("Waiting for AI processing to finish...")
        for sec in range(40):
            time.sleep(1)
            body_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
            if "Menghitung & Mencocokkan Harga" not in body_text and ("Total Estimasi" in body_text or "Good Day" in body_text or "Royco" in body_text):
                ai_success = True
                print(f"AI Response completed and rendered at second {sec+1}!")
                break
            if "Gagal Memanggil AI" in body_text:
                print(f"AI Call failed with dialog error at second {sec+1}!")
                break

        driver.save_screenshot("evidence/e2e_05_after_ai_calculation.png")
        
        # Check browser console errors
        logs = driver.get_log('browser')
        errors = [l['message'] for l in logs if l['level'] in ['SEVERE', 'ERROR']]
        
        print(f"[TC-06] Evidence saved. Browser console errors: {len(errors)}")
        for err in errors:
            print("  ERR:", err)

        # Final Semantics dump
        final_text = driver.find_element(By.TAG_NAME, 'flt-semantics-host').text
        print("Final Screen text snippet:")
        print(final_text[:500])

    finally:
        driver.quit()

if __name__ == "__main__":
    run_e2e()
