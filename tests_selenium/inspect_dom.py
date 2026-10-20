import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

chrome_options = Options()
chrome_options.add_argument('--headless=new')
chrome_options.add_argument('--window-size=1280,900')
driver = webdriver.Chrome(options=chrome_options)
driver.get('http://localhost:8089')
time.sleep(3)

views = driver.find_elements('tag name', 'flutter-view')
print('flutter-view count:', len(views))
if views:
    shadow_root = driver.execute_script('return arguments[0].shadowRoot;', views[0])
    print('shadowRoot present:', shadow_root is not None)
    if shadow_root:
        # Check semantics host or placeholder
        placeholder = driver.execute_script("return arguments[0].querySelector('flt-semantics-placeholder');", shadow_root)
        print('flt-semantics-placeholder:', placeholder is not None)
        if placeholder:
            print('Clicking semantics placeholder to enable full accessibility DOM tree...')
            driver.execute_script("arguments[0].click();", placeholder)
            time.sleep(2)
        
        # Now query all elements inside shadow root
        elems = driver.execute_script("return arguments[0].querySelectorAll('*');", shadow_root)
        print(f'Total elements in shadowRoot: {len(elems)}')
        for el in elems:
            tag = driver.execute_script("return arguments[0].tagName;", el)
            aria = driver.execute_script("return arguments[0].getAttribute('aria-label');", el)
            role = driver.execute_script("return arguments[0].getAttribute('role');", el)
            if aria or role in ['button', 'textbox', 'dialog', 'alert']:
                print(f"  <{tag}> role='{role}' aria-label='{aria}'")

driver.quit()
