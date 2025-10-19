#!/bin/bash

# Migration script to replace old files with new refactored structure
# This script backs up the old files and replaces them with the new feature-based architecture

echo "🔄 Starting migration to feature-based architecture..."

# Create backup directory
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup in $BACKUP_DIR..."

# Backup old files
cp src/services/authentication_service.lua "$BACKUP_DIR/"
cp src/services/device_service.lua "$BACKUP_DIR/"
cp src/services/scenes_service.lua "$BACKUP_DIR/"
cp src/services/color_converter.lua "$BACKUP_DIR/"
cp src/services/http_client.lua "$BACKUP_DIR/"
cp src/services/logger.lua "$BACKUP_DIR/"
cp src/services/container.lua "$BACKUP_DIR/"
cp src/service_factory.lua "$BACKUP_DIR/"
cp src/twinkly.lua "$BACKUP_DIR/"

echo "✅ Backup completed"

# Replace old files with new ones
echo "🔄 Replacing files with new structure..."

# Replace services
cp src/services/authentication_service_new.lua src/services/authentication_service.lua
cp src/services/device_service_new.lua src/services/device_service.lua
cp src/services/scenes_service_new.lua src/services/scenes_service.lua
cp src/services/color_converter_new.lua src/services/color_converter.lua

# Replace main files
cp src/service_factory_new.lua src/service_factory.lua
cp src/twinkly_new.lua src/twinkly.lua

# Move infrastructure files
mv src/infrastructure/http_client.lua src/services/http_client.lua
mv src/infrastructure/logger.lua src/services/logger.lua
mv src/infrastructure/container.lua src/services/container.lua

echo "✅ Files replaced successfully"

# Clean up temporary files
echo "🧹 Cleaning up temporary files..."
rm -f src/services/authentication_service_new.lua
rm -f src/services/device_service_new.lua
rm -f src/services/scenes_service_new.lua
rm -f src/services/color_converter_new.lua
rm -f src/service_factory_new.lua
rm -f src/twinkly_new.lua
rm -rf src/infrastructure

echo "✅ Cleanup completed"

# Test the new structure
echo "🧪 Testing new structure..."
cd tests
LUA_PATH="../src/?.lua;../src/?/?.lua;../src/?/init.lua;;" lua run-specific-integration-test.lua random_effect

if [ $? -eq 0 ]; then
    echo "✅ Migration completed successfully!"
    echo "📁 Old files backed up to: $BACKUP_DIR"
    echo "🎉 The codebase now uses a feature-based architecture with improved findability and readability"
else
    echo "❌ Migration test failed. Check the logs above."
    echo "🔄 You can restore from backup: $BACKUP_DIR"
    exit 1
fi
