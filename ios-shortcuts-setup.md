# iOS Shortcuts — Save to Reading List

Save links to your reading list from **any iOS app** (Safari, RSS readers, Threads, Apple News) using the native Share Sheet. No app to install, no developer account needed.

**How it works:** Your iOS Shortcut sends a POST request directly to your Supabase database's REST API. The same `links` table your reading list page already uses.

---

## Prerequisites

You need one thing from your Supabase dashboard:

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) → your project → **Settings** → **API**
2. Copy your **service_role key** (the secret one, NOT the anon/public key)
3. Keep it handy — you'll paste it into the shortcuts below

> **Why the service role key?** Your `links` table likely has Row Level Security (RLS) enabled. The service role key bypasses RLS, letting the shortcut insert without a full login flow. This key stays on your device only.

---

## Shortcut A: "Quick Save" (one-tap)

This is the fast one. Tap share → tap shortcut → done. Saves with default category and 3 stars.

### Steps to create:

1. Open the **Shortcuts** app on your iPhone/iPad
2. Tap **+** to create a new shortcut
3. Tap the name at the top and rename it to **"Quick Save"**
4. Tap the **ⓘ** (info) button at the bottom → enable **"Show in Share Sheet"**
5. Under "Share Sheet Types", keep **URLs** and **Safari web pages** selected

Now add these actions in order:

#### Action 1: Get URLs from Input
- Search for **"URLs"** in the actions search bar
- Add **"Get URLs from Input"**
- It should say: `Get URLs from Shortcut Input`

#### Action 2: Set Variable — save the URL
- Add **"Set Variable"**
- Tap "Variable Name" and type: `linkURL`
- Input should be: `URLs`

#### Action 3: Get the page title
- Add **"Get Name"**
- Set input to: `linkURL` variable
- This extracts the page title from the URL

#### Action 4: Set Variable — save the title
- Add **"Set Variable"**
- Tap "Variable Name" and type: `pageTitle`

#### Action 5: Format the current date
- Add **"Format Date"**
- Set to: `Current Date`
- Date Format: **Custom** → `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`

#### Action 6: Set Variable — save the date
- Add **"Set Variable"**
- Variable Name: `savedAt`

#### Action 7: Get domain from URL
- Add **"Get Details of URLs"** (under "Get Component of URL")
- Set to get: **Host**
- From: `linkURL` variable

#### Action 8: Set Variable — save the domain
- Add **"Set Variable"**
- Variable Name: `domain`

#### Action 9: Build the JSON body
- Add **"Text"** action
- Paste this (tap and hold to paste):

```
{"id":"shortcut-CURRENTDATE","url":"LINKURL","title":"PAGETITLE","description":"","image":"","favicon":"https://www.google.com/s2/favicons?domain=DOMAIN&sz=64","domain":"DOMAIN","category":"Uncategorized","stars":3,"note":"","private":false,"saved_at":"SAVEDAT"}
```

Now replace the placeholder words with variables:
- Select `CURRENTDATE` → tap "Variable" → "Current Date" → format as **Custom**: `yyyyMMddHHmmss`
- Select `LINKURL` → tap "Variable" → choose `linkURL`
- Select `PAGETITLE` → tap "Variable" → choose `pageTitle`
- Select both instances of `DOMAIN` → tap "Variable" → choose `domain`
- Select `SAVEDAT` → tap "Variable" → choose `savedAt`

#### Action 10: Set Variable — save the body
- Add **"Set Variable"**
- Variable Name: `requestBody`

#### Action 11: Send the POST request
- Add **"Get Contents of URL"**
- URL: `https://ownqyyfgferczpdgihgr.supabase.co/rest/v1/links`
- Method: **POST**
- Headers — add these three:
  | Key | Value |
  |-----|-------|
  | `apikey` | `sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y` |
  | `Authorization` | `Bearer YOUR_SERVICE_ROLE_KEY` |
  | `Content-Type` | `application/json` |
  | `Prefer` | `return=minimal` |
- Request Body: **File** → select `requestBody` variable

> **IMPORTANT:** Replace `YOUR_SERVICE_ROLE_KEY` with your actual service role key from the Supabase dashboard.

#### Action 12: Show notification
- Add **"Show Notification"**
- Title: `Saved!`
- Body: `pageTitle` variable

### Done! Test it:
1. Open Safari and navigate to any article
2. Tap the **Share** button
3. Scroll down and tap **"Quick Save"**
4. You should see a "Saved!" notification
5. Check your reading list page — the link should appear

---

## Shortcut B: "Save to Reading List" (with options)

Same as above but prompts you for category, note, and rating before saving.

### Steps to create:

1. Create a new shortcut, name it **"Save to Reading List"**
2. Enable **"Show in Share Sheet"** (same as above)
3. Add Actions 1–8 from Shortcut A (get URL, title, date, domain)

Then continue with:

#### Action 9: Choose category
- Add **"Choose from Menu"**
- Prompt: `Category`
- Add these menu items (customize to match your categories):
  - Tech
  - Design
  - Long Reads
  - Politics
  - Business
  - Uncategorized
- Under **each menu item**, add a **"Set Variable"** action:
  - Variable Name: `category`
  - Value: the category name (e.g., "Tech")

#### Action 10: Ask for a note (optional)
- Add **"Ask for Input"**
- Input Type: **Text**
- Prompt: `Note (optional)`
- Default Answer: *(leave empty)*

#### Action 11: Set Variable — save the note
- Add **"Set Variable"**
- Variable Name: `note`

#### Action 12: Choose rating
- Add **"Choose from List"**
- List items: `1`, `2`, `3`, `4`, `5`
- Prompt: `Rating`

#### Action 13: Set Variable — save the rating
- Add **"Set Variable"**
- Variable Name: `stars`

#### Action 14: Build the JSON body
- Add **"Text"** action
- Same as Shortcut A's JSON but use the `category`, `note`, and `stars` variables instead of the hardcoded defaults

#### Action 15: POST to Supabase
- Same as Shortcut A's Action 11

#### Action 16: Show notification
- Same as Shortcut A's Action 12

---

## Troubleshooting

**"The request returned an error"**
- Double-check your service role key (not the anon key) in the Authorization header
- Make sure the URL format is `Bearer <key>` (with a space after Bearer)
- Check that all JSON fields are present in the request body

**Link appears but has no title**
- Some sites block server-side title fetching. The "Get Name" action in Shortcuts may return empty
- You can edit the title on your reading list page (admin mode)

**Duplicate IDs**
- The ID includes a timestamp, so duplicates are extremely unlikely
- If it happens, the POST will fail — just try again

**Link doesn't show up on the site**
- Check if it was saved as `private: true`
- Check if "Uncategorized" is filtered out — click "All" in the filter tabs
- Log in as admin to see all links

---

## Quick Reference

**Supabase REST API endpoint:**
```
POST https://ownqyyfgferczpdgihgr.supabase.co/rest/v1/links
```

**Required headers:**
```
apikey: sb_publishable_RPJSQlVO4isbKnZve8NlWg_55EO350Y
Authorization: Bearer <your-service-role-key>
Content-Type: application/json
Prefer: return=minimal
```

**Minimum JSON body:**
```json
{
  "id": "unique-id-here",
  "url": "https://example.com",
  "title": "Page Title",
  "description": "",
  "image": "",
  "favicon": "https://www.google.com/s2/favicons?domain=example.com&sz=64",
  "domain": "example.com",
  "category": "Uncategorized",
  "stars": 3,
  "note": "",
  "private": false,
  "saved_at": "2026-03-16T12:00:00.000Z"
}
```
