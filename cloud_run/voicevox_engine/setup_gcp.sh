#!/bin/bash

# GCP Setup Script for VOICEVOX Engine Deployment

echo "=== GCP Setup for VOICEVOX Engine ==="
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK (gcloud) is not installed."
    echo ""
    echo "Please install it using one of these methods:"
    echo ""
    echo "Option 1: Using Homebrew (recommended for macOS):"
    echo "  brew install --cask google-cloud-sdk"
    echo ""
    echo "Option 2: Download from Google:"
    echo "  https://cloud.google.com/sdk/docs/install"
    echo ""
    echo "After installation, run this script again."
    exit 1
fi

echo "✅ Google Cloud SDK is installed"
echo ""

# Set project
PROJECT_ID="myproject-c8034"
echo "Setting up project: ${PROJECT_ID}"

# Initialize gcloud and authenticate
echo "1. Authenticating with Google Cloud..."
gcloud auth login

echo ""
echo "2. Setting default project..."
gcloud config set project ${PROJECT_ID}

echo ""
echo "3. Configuring Docker for Google Container Registry..."
gcloud auth configure-docker

echo ""
echo "4. Enabling required APIs..."
gcloud services enable containerregistry.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

echo ""
echo "5. Checking current configuration..."
echo "Current project: $(gcloud config get-value project)"
echo "Current account: $(gcloud config get-value account)"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "You can now run ./deploy.sh to deploy VOICEVOX Engine to Cloud Run."
echo ""
echo "Note: Make sure Docker is running before deploying."