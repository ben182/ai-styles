#!/bin/bash

# AI Coding Styles Installation Script
# This script downloads coding guidelines to .ai/guidelines/

set -e

REPO_BASE_URL="https://raw.githubusercontent.com/ben182/ai-styles/main"
INSTALL_DIR=".ai/guidelines"

echo "🤖 Installing Laravel AI coding guidelines (Laravel Boost optimized)..."

# Create directory
mkdir -p "$INSTALL_DIR"

# Download guidelines
echo "📥 Downloading ben-coding-style.md..."
curl -sSL "$REPO_BASE_URL/ben-coding-style.md" -o "$INSTALL_DIR/ben-coding-style.blade.php"

# Fix HTML conflicts for Blade compatibility
echo "🔧 Fixing HTML conflicts for Blade compatibility..."
sed -i.bak \
    -e 's/<!--/{{-- /g' \
    -e 's/-->/--}}/g' \
    -e 's/<option value="/\&lt;option value=\&quot;/g' \
    -e 's/<\/option>/\&lt;\/option\&gt;/g' \
    -e 's/@selected/@<!-- selected -->/g' \
    -e 's/@checked/@<!-- checked -->/g' \
    -e 's/@foreach/@<!-- foreach -->/g' \
    -e 's/@endforeach/@<!-- endforeach -->/g' \
    -e 's/{{ /\&lbrace;\&lbrace; /g' \
    -e 's/ }}/ \&rbrace;\&rbrace;/g' \
    "$INSTALL_DIR/ben-coding-style.blade.php"

# Clean up backup file
rm -f "$INSTALL_DIR/ben-coding-style.blade.php.bak"

echo "✅ AI coding guidelines installed to $INSTALL_DIR/"
echo "🔄 To update, simply run this command again."
echo ""
echo "Your AI assistant can now access these Laravel Boost coding standards for:"
echo "  • Laravel Action patterns"
echo "  • Domain-driven organization" 
echo "  • Clean architecture principles"
echo "  • Code style conventions"