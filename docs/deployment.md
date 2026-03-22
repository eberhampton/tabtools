# TabTools.dev — Deployment Guide

## Server Details

- **Provider:** DigitalOcean
- **Droplet tier:** $4/mo (512MB RAM, 10GB SSD)
- **OS:** Ubuntu 24.04 LTS
- **IP:** 146.190.133.14
- **Domain:** tabtools.dev (registered on Namecheap)
- **Deploy user:** eber
- **Web root:** /var/www/tabtools.dev

---

## 1. Droplet Creation

- Created Ubuntu 24.04 LTS droplet on DigitalOcean ($4/mo)
- Region: San Francisco
- Added existing SSH key during creation
- Hostname: Tabtools

## 2. Initial System Update

```bash
ssh root@146.190.133.14
apt update && apt upgrade -y
```

Accepted package maintainer's version of sshd_config when prompted.

## 3. Create Deploy User

```bash
adduser eber
usermod -aG sudo eber
```

Copy SSH key to new user:

```bash
mkdir -p /home/eber/.ssh
cp /root/.ssh/authorized_keys /home/eber/.ssh/authorized_keys
chown -R eber:eber /home/eber/.ssh
chmod 700 /home/eber/.ssh
chmod 600 /home/eber/.ssh/authorized_keys
```

Verify login works in a separate terminal before proceeding:

```bash
ssh eber@146.190.133.14
```

## 4. SSH Hardening

Edit SSH config:

```bash
sudo nano /etc/ssh/sshd_config
```

Set these values:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Restart SSH:

```bash
sudo systemctl restart ssh
```

Verify: `ssh eber@` works, `ssh root@` is denied.

## 5. Firewall (UFW)

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
sudo ufw status
```

Only ports 22, 80, 443 are open.

## 6. Fail2ban

```bash
sudo apt install fail2ban -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

In the `[sshd]` section:

```
[sshd]
enabled = true
port = ssh
maxretry = 5
findtime = 600
bantime = 3600
```

Start and enable:

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo fail2ban-client status sshd
```

## 7. nginx

Install:

```bash
sudo apt install nginx -y
```

Create web root:

```bash
sudo mkdir -p /var/www/tabtools.dev
sudo chown -R eber:eber /var/www/tabtools.dev
```

Create site config:

```bash
sudo nano /etc/nginx/sites-available/tabtools.dev
```

```nginx
server {
    listen 80;
    server_name tabtools.dev www.tabtools.dev;

    root /var/www/tabtools.dev;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Enable and start:

```bash
sudo ln -s /etc/nginx/sites-available/tabtools.dev /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

## 8. DNS

On Namecheap, under Advanced DNS for tabtools.dev:

- A Record — Host: `@` — Value: `146.190.133.14`
- A Record — Host: `www` — Value: `146.190.133.14`

## 9. SSL (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d tabtools.dev -d www.tabtools.dev
```

- Accepted redirect HTTP → HTTPS
- Certificate auto-renews via certbot scheduled task
- Certificate expires: 2026-06-20

## 10. Deploying Updates

*To be defined — see Issue #8.*

Options under consideration:
- SCP from local Mac (like bobrew.dev)
- Git pull on server from main branch
- Deploy script that automates the pull and restarts

---

## Quick Reference

SSH into server:
```bash
ssh eber@146.190.133.14
```

Restart nginx:
```bash
sudo systemctl restart nginx
```

Test nginx config:
```bash
sudo nginx -t
```

Check Fail2ban status:
```bash
sudo fail2ban-client status sshd
```

Check UFW status:
```bash
sudo ufw status
```

Check SSL certificate:
```bash
sudo certbot certificates
```
