#!/bin/bash

# Git Setup Script for KINS App
# Run this script to upload code to GitHub

echo "🚀 Setting up Git repository..."

# Initialize git (if not already initialized)
if [ ! -d .git ]; then
    git init
fi

# Add remote (or update if exists)
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/otahir-21/kins.git

# Set branch to main
git branch -M main

# Add all files
echo "📦 Adding files..."
git add .

# Commit
echo "💾 Committing changes..."
git commit -m "Initial commit: KINS App with Firebase Auth, Firestore, and Bunny CDN integration"

# Push to GitHub
echo "📤 Pushing to GitHub..."
git push -u origin main

echo "✅ Done! Your code is now on GitHub: https://github.com/otahir-21/kins"
