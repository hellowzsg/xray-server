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
    echo "  init <domain> <email>  - Apply for a new certificate"
    echo "  renew                  - Renew all certificates"
    echo "  test <domain> <email>  - Test certificate application (dry-run)"
    echo ""
    echo "Examples:"
    echo "  $0 init example.com admin@example.com"
    echo "  $0 renew"
    echo "  $0 test example.com admin@example.com"
}

case "$ACTION" in
    init)
        if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
            echo "Error: domain and email are required for init"
            usage
            exit 1
        fi
        echo "Applying for certificate for $DOMAIN..."
        docker compose run --rm certbot certonly --webroot \
            --webroot-path=/var/www/certbot \
            -d "$DOMAIN" \
            --email "$EMAIL" \
            --agree-tos \
             --staging \
            --no-eff-email
        echo "Certificate obtained! Reloading nginx..."
        docker compose exec nginx nginx -s reload
        ;;
    renew)
        echo "Renewing certificates..."
        docker compose run --rm certbot renew
        echo "Reloading nginx..."
        docker compose exec nginx nginx -s reload
        ;;
    test)
        if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
            echo "Error: domain and email are required for test"
            usage
            exit 1
        fi
        echo "Testing certificate application for $DOMAIN (dry-run)..."
        docker compose run --rm certbot certonly --webroot \
            --webroot-path=/var/www/certbot \
            -d "$DOMAIN" \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --dry-run
        ;;
    *)
        usage
        exit 1
        ;;
esac
