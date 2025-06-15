# VOICEVOX Engine Cloud Run Deployment Guide

## Prerequisites Checklist

### ✅ Already Configured
- **GCP Project ID**: `myproject-c8034` (found in firebase.json)
- **Docker**: Installed (version 28.0.4)
- **deploy.sh**: Already has correct project ID

### ❌ Needs Setup
- **Google Cloud SDK (gcloud)**: Not installed
- **GCP Authentication**: Not configured
- **Docker Registry Authentication**: Not configured

## Step-by-Step Deployment Instructions

### Step 1: Install Google Cloud SDK

Since you're on macOS, the easiest way is using Homebrew:

```bash
brew install --cask google-cloud-sdk
```

After installation, restart your terminal or run:
```bash
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
```

### Step 2: Run the Setup Script

I've created a setup script that will handle all the GCP configuration:

```bash
cd /Users/hundlename/_dont_think_write_Talkone/TalkOne/cloud_run/voicevox_engine
./setup_gcp.sh
```

This script will:
1. Authenticate you with Google Cloud
2. Set your default project to `myproject-c8034`
3. Configure Docker to work with Google Container Registry
4. Enable required APIs

### Step 3: Deploy VOICEVOX Engine

Once setup is complete, deploy with:

```bash
./deploy.sh
```

## Troubleshooting

### Authentication Errors
If you get authentication errors, run:
```bash
gcloud auth login
gcloud auth configure-docker
```

### Project Not Found
If the project `myproject-c8034` is not found, make sure:
1. You're logged in with the correct Google account
2. The project exists in your Google Cloud Console
3. You have necessary permissions

### Docker Push Errors
If Docker can't push to gcr.io, ensure:
1. Docker Desktop is running
2. You've run `gcloud auth configure-docker`
3. Your account has Storage Admin permissions on the project

### API Not Enabled Errors
Enable required APIs manually:
```bash
gcloud services enable containerregistry.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

## Verification

After successful deployment, you'll get a Cloud Run URL. Test it with:

```bash
curl https://your-service-url.run.app/speakers
```

This should return a list of available VOICEVOX speakers.

## Integration with Flutter App

Once deployed, update your Flutter app's VoiceVoxService:

1. Open `/lib/services/voicevox_service.dart`
2. Replace the `_defaultHost` with your Cloud Run URL
3. Rebuild your Flutter app

## Estimated Costs

Based on typical usage:
- **Cloud Run**: ~$0.10-$1.00/month (pay per request)
- **Container Registry Storage**: ~$0.10/month
- **Network Egress**: ~$0.12/GB

Total: Usually under $5/month for moderate usage