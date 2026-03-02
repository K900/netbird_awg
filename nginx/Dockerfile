FROM nginx:1.27-alpine

ARG RELEASE_VERSION=0.66.0-awg-r1
ARG GITHUB_REPO=spikeyspik/netbird_awg

RUN cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;

    location = /install {
        return 302 https://github.com/${GITHUB_REPO}/releases/tag/v${RELEASE_VERSION};
    }

    location = /macos/amd64 {
        return 302 https://github.com/${GITHUB_REPO}/releases/download/v${RELEASE_VERSION}/netbird_${RELEASE_VERSION}_darwin_amd64.pkg;
    }

    location = /macos/arm64 {
        return 302 https://github.com/${GITHUB_REPO}/releases/download/v${RELEASE_VERSION}/netbird_${RELEASE_VERSION}_darwin_arm64.pkg;
    }

    location = /windows/x64 {
        return 302 https://github.com/${GITHUB_REPO}/releases/download/v${RELEASE_VERSION}/netbird_installer_${RELEASE_VERSION}_windows_amd64.exe;
    }

    location = /windows/arm64 {
        return 302 https://github.com/${GITHUB_REPO}/releases/download/v${RELEASE_VERSION}/netbird_installer_${RELEASE_VERSION}_windows_arm64.exe;
    }

    location = /releases/latest/version {
        default_type text/plain;
        return 200 "${RELEASE_VERSION}";
    }

    location / {
        return 302 https://github.com/${GITHUB_REPO};
    }
}
EOF
