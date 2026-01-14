#!/bin/bash
set -e

cd "$(dirname "$0")"

ACTION=${1:-}
DOMAIN=${2:-}
EMAIL=${3:-}

usage() {
    echo "Usage: $0 <action> [domain] [email]"
    echo ""
    echo "Actions:"
    echo "  init <domain> <email>  - Apply for a new certificate (DNS-01 via Cloudflare)"
    echo "  renew                  - Renew all certificates"
    echo "  test <domain> <email>  - Test certificate application (dry-run)"
    echo "  list                   - List all certificates"
    echo ""
    echo "Examples:"
    echo "  $0 init example.com admin@example.com"
    echo "  $0 renew"
    echo "  $0 test example.com admin@example.com"
    echo ""
    echo "Note: Before using, edit certbot/cloudflare.ini with your Cloudflare API Token"
}

# Check if cloudflare.ini is configured
check_cloudflare_config() {
    if grep -q "YOUR_CLOUDFLARE_API_TOKEN_HERE" ./certbot/cloudflare.ini 2>/dev/null; then
        echo "Error: Please configure your Cloudflare API Token in certbot/cloudflare.ini"
        exit 1
    fi
}

case "$ACTION" in
    init)
        if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
            echo "Error: domain and email are required for init"
            usage
            exit 1
        fi
        check_cloudflare_config
        echo "Applying for certificate for $DOMAIN using DNS-01 (Cloudflare)..."
        docker compose run --rm --entrypoint certbot certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
            --dns-cloudflare-propagation-seconds 30 \
            -d "$DOMAIN" \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email
        
        # Create symbolic link to www directory
        echo "Creating symbolic link for certificate..."
        WWW_SSL_DIR="./www/$DOMAIN/ssl"
        CERT_DIR="./certbot/conf/live/$DOMAIN"
        
        if [ -d "$CERT_DIR" ]; then
            mkdir -p "./www/$DOMAIN"
            # Remove old link if exists
            [ -L "$WWW_SSL_DIR" ] && rm "$WWW_SSL_DIR"
            # Remove directory if exists (to replace with link)
            [ -d "$WWW_SSL_DIR" ] && rm -rf "$WWW_SSL_DIR"
            # Create symbolic link (ssl directory itself links to certificate directory)
            ln -sf "$(pwd)/$CERT_DIR" "$WWW_SSL_DIR"
            echo "Certificate linked to $WWW_SSL_DIR"
        else
            echo "Warning: Certificate directory $CERT_DIR not found"
        fi
        
        echo "Certificate obtained! Reloading nginx..."
        docker compose exec nginx nginx -s reload
        ;;
    renew)
        echo "Renewing certificates..."
        docker compose run --rm --entrypoint certbot certbot renew
        echo "Reloading nginx..."
        docker compose exec nginx nginx -s reload
        ;;
    test)
        if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
            echo "Error: domain and email are required for test"
            usage
            exit 1
        fi
        check_cloudflare_config
        echo "Testing certificate application for $DOMAIN (dry-run)..."
        docker compose run --rm --entrypoint certbot certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
            --dns-cloudflare-propagation-seconds 30 \
            -d "$DOMAIN" \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --dry-run
        ;;
    list)
        echo "Listing certificates..."
        docker compose run --rm --entrypoint certbot certbot certificates
        ;;
    *)
        usage
        exit 1
        ;;
esac
