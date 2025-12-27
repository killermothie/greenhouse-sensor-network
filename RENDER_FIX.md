# Render Deployment Fix - PORT Variable Issue

## Problem
Render is showing `--port $P` instead of expanding `$PORT` correctly.

## Solution Options

### Option 1: Update Start Command in Render Dashboard (RECOMMENDED)

1. Go to your Render dashboard: https://dashboard.render.com
2. Click on your service: `greenhouse-sensor-api`
3. Go to **Settings** tab
4. Scroll to **Start Command**
5. Replace the current command with:
   ```
   bash start.sh
   ```
6. Click **Save Changes**
7. Render will automatically redeploy

### Option 2: Use Direct Command (Alternative)

If the script doesn't work, use this command directly in Render dashboard:

```
uvicorn main:app --host 0.0.0.0 --port ${PORT}
```

Or if that still doesn't work:

```
sh -c "uvicorn main:app --host 0.0.0.0 --port \$PORT"
```

### Option 3: Use Python Script (Most Reliable)

If both above fail, we can modify `main.py` to handle PORT automatically. But try Option 1 first!

## Why This Happens

Render's `render.yaml` file might not be automatically applied if:
- The service was created manually in the dashboard
- The dashboard settings override the YAML file
- The YAML file format isn't recognized

The dashboard settings take precedence, so you need to update it there.

