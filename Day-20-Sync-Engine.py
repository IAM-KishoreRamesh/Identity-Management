# [SANITIZED ON 2026-07-05] SECURITY AUDIT: Hardcoded tenant IDs, credentials, and user emails replaced with generic placeholders for public repo.
import json
import requests
import msal

# --- 1. CONFIGURATION & CREDENTIALS ---
TENANT_ID = "<YOUR_TENANT_NAME>.onmicrosoft.com"
CLIENT_ID = "<YOUR_CLIENT_ID"
CLIENT_SECRET = "YOUR_CLIENT_SECRET" 

AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"
SCOPES = ["https://graph.microsoft.com/.default"]

print("Initiating OIM-to-Entra ID Sync Engine...")

# --- 2. HEADLESS AUTHENTICATION ---
# The script authenticates as a machine, bypassing human MFA requirements.
app = msal.ConfidentialClientApplication(
    CLIENT_ID, authority=AUTHORITY, client_credential=CLIENT_SECRET
)

result = app.acquire_token_silent(SCOPES, account=None)
if not result:
    result = app.acquire_token_for_client(scopes=SCOPES)

if "access_token" not in result:
    print(f"FATAL ERROR: Authentication failed. {result.get('error_description')}")
    exit(1)

access_token = result["access_token"]
print("SUCCESS: Machine token acquired. Bridge is active.")

# --- 3. READ LOCAL OIM STATE ---
try:
    with open('OIM_Export_State.json', 'r') as file:
        oim_data = json.load(file)
except FileNotFoundError:
    print("FATAL ERROR: OIM_Export_State.json not found.")
    exit(1)

headers = {
    'Authorization': f'Bearer {access_token}',
    'Content-Type': 'application/json'
}

# --- 4. EXECUTE GRAPH API PAYLOAD ---
for user in oim_data['users']:
    if user['status'] == 'Terminated':
        target_upn = user['userPrincipalName']
        print(f"ACTION: HR Termination detected. Severing cloud access for {target_upn}...")
        
        # This payload physically disables the Entra ID account
        payload = {"accountEnabled": False}
        graph_url = f"https://graph.microsoft.com/v1.0/users/{target_upn}"
        
        response = requests.patch(graph_url, headers=headers, json=payload)
        
        if response.status_code == 204:
            print(f"SUCCESS: {target_upn} has been securely locked out of Entra ID.")
        else:
            print(f"API FAILURE: {response.status_code} - {response.text}")
