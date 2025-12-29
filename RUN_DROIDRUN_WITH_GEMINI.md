# Running Droidrun with Google Gemini in Termux

## Setup Google Gemini API Key

### Option 1: Environment Variable (Recommended)
```bash
export GOOGLE_API_KEY="your-api-key-here"
# Or
export GEMINI_API_KEY="your-api-key-here"
```

### Option 2: Set in Termux Session
```bash
# In Termux terminal
export GOOGLE_API_KEY="your-api-key-here"
```

## Commands to Run Droidrun in Termux

### 1. List Devices
```bash
python3 -m droidrun devices
```

### 2. Ping Device
```bash
python3 -m droidrun ping
```

### 3. Run Command with Google Gemini
```bash
# Set API key first
export GOOGLE_API_KEY="your-api-key-here"

# Run a command
python3 -m droidrun run "open settings app" --provider GoogleGenAI --model gemini-pro
```

### 4. Run with Vision Enabled
```bash
export GOOGLE_API_KEY="your-api-key-here"
python3 -m droidrun run "take a screenshot" --provider GoogleGenAI --model gemini-pro-vision --vision
```

### 5. Run with Streaming
```bash
export GOOGLE_API_KEY="your-api-key-here"
python3 -m droidrun run "list all installed apps" --provider GoogleGenAI --model gemini-pro --stream
```

## Complete Example Command

```bash
# In Termux terminal
export PATH=/data/data/com.termux/files/usr/bin:$PATH
export HOME=/data/data/com.termux/files/home
export GOOGLE_API_KEY="your-api-key-here"

python3 -m droidrun run "open calculator app" \
  --provider GoogleGenAI \
  --model gemini-pro \
  --stream \
  --vision
```

## Make API Key Persistent

Add to `~/.bashrc` or `~/.profile`:
```bash
echo 'export GOOGLE_API_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

