#!/bin/bash

# Build script for Samba AD + LAM combined container
# Usage: ./build.sh [tag]
#
# NOTE: If using GitHub + Docker Hub auto-build, you don't need this script!
#       Just push to GitHub and images build automatically.
#       See GITHUB-SETUP.md for details.

set -e

# Configuration
IMAGE_NAME="ryan-haver/samba-ad-lam"
DEFAULT_TAG="latest"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Use provided tag or default
TAG="${1:-$DEFAULT_TAG}"
FULL_IMAGE="${IMAGE_NAME}:${TAG}"

echo "============================================"
echo "Building Samba AD + LAM Container (Local)"
echo "============================================"
echo "Image: ${FULL_IMAGE}"
echo "Build Date: ${BUILD_DATE}"
echo "VCS Ref: ${VCS_REF}"
echo ""
echo "💡 TIP: For automated builds, see GITHUB-SETUP.md"
echo "============================================"
echo ""

# Build the image
echo "Starting Docker build..."
docker build \
  --build-arg BUILD_DATE="${BUILD_DATE}" \
  --build-arg VCS_REF="${VCS_REF}" \
  --tag "${FULL_IMAGE}" \
  --tag "${IMAGE_NAME}:latest" \
  .

echo ""
echo "============================================"
echo "Build completed successfully!"
echo "============================================"
echo ""
echo "Image: ${FULL_IMAGE}"
echo "Size: $(docker images ${FULL_IMAGE} --format '{{.Size}}')"
echo ""
echo "Next steps:"
echo "  1. Test the image locally:"
echo "     docker run --rm ${FULL_IMAGE} samba --version"
echo ""
echo "  2. Push to Docker Hub (manual):"
echo "     docker login"
echo "     docker push ${FULL_IMAGE}"
echo ""
echo "  3. OR set up automated builds:"
echo "     See GITHUB-SETUP.md for GitHub Actions setup"
echo ""
echo "  4. Deploy to Unraid:"
echo "     Use the Unraid template to pull from Docker Hub"
echo ""
