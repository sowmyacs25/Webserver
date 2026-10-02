#!/bin/bash
# ================================================================
# setup_dc.sh — Active Directory Domain Controller Configuration
# (Samba 4 AD DC Simulation for VulnCorp int-dc01)
# ================================================================
set -e

echo "[*] Provisioning Samba Active Directory Domain Controller..."

# Disable unneeded services during build
service smbd stop 2>/dev/null || true
service nmbd stop 2>/dev/null || true
service winbind stop 2>/dev/null || true

# Remove default smb.conf before provisioning
rm -f /etc/samba/smb.conf /etc/krb5.conf /var/lib/samba/private/*.ldb 2>/dev/null || true

# 1. Provision Active Directory Domain
samba-tool domain provision \
  --realm=VULNCORP.LOCAL \
  --domain=VULNCORP \
  --adminpass='Corp@Admin2024' \
  --server-role=dc \
  --dns-backend=SAMBA_INTERNAL \
  --option="server signing = no" \
  --option="client signing = no" \
  --option="ldap server require strong auth = no" \
  --option="ntlm auth = yes" \
  --option="dsdb:schema update allowed = yes"

# Configure Kerberos
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

# 2. Create Domain Users
echo "[*] Creating Active Directory users..."

samba-tool user create john.doe 'Corp@Admin2024' \
  --description="IT Systems Administrator" \
  --userou="CN=Users"

samba-tool user create jane.smith 'Jane@Dev2024' \
  --description="Senior Software Developer" \
  --userou="CN=Users"

samba-tool user create helpdesk 'Helpdesk@123' \
  --description="IT Help Desk Support - Flag: VULN{p4ssw0rd_spr4y_h1t}" \
  --userou="CN=Users"

samba-tool user create svc_backup 'Backup@Svc2024' \
  --description="Automated Backup Service Account - Flag: VULN{4sr3p_r04st_cr4ck3d}" \
  --userou="CN=Users"

samba-tool user create svc_erp 'Erp@Service99!' \
  --description="Enterprise Resource Planning Service - Flag: VULN{k3rb3r04st_svc_pwn3d}" \
  --userou="CN=Users"

samba-tool user create svc_sql 'Sql@Service77!' \
  --description="Production Database SQL Service" \
  --userou="CN=Users"

# 3. Group Memberships & Privileges
echo "[*] Configuring group memberships..."
samba-tool group addmembers "Domain Admins" john.doe
samba-tool group addmembers "Administrators" svc_backup

# Update krbtgt description with DCSync Flag
cat << 'EOF' | ldbmodify -H /var/lib/samba/private/sam.ldb
dn: CN=krbtgt,CN=Users,DC=vulncorp,DC=local
changetype: modify
replace: description
description: Key Distribution Center Master Key - Flag: VULN{dcs1nc_h4sh_dump3d}
EOF

# 4. Vulnerability 1: AS-REP Roasting (Disable Kerberos Pre-Authentication)
echo "[*] Enabling AS-REP Roasting on svc_backup..."
# userAccountControl: 512 (Normal) + 4194304 (DONT_REQ_PREAUTH) = 4194816 (0x400200)
cat << 'EOF' | ldbmodify -H /var/lib/samba/private/sam.ldb
dn: CN=svc_backup,CN=Users,DC=vulncorp,DC=local
changetype: modify
replace: userAccountControl
userAccountControl: 4194816
EOF
echo "[+] svc_backup is now AS-REP roastable (DONT_REQ_PREAUTH enabled)"

# 5. Vulnerability 2: Kerberoasting (Register SPNs)
echo "[*] Registering SPNs for Kerberoasting..."
samba-tool spn add HTTP/erp.vulncorp.local:80 svc_erp
samba-tool spn add HTTP/erp.vulncorp.local svc_erp
samba-tool spn add HTTP/VULNCORP-ERP01 svc_erp
samba-tool spn add MSSQLSvc/sql.vulncorp.local:1433 svc_sql
samba-tool spn add MSSQLSvc/sql.vulncorp.local svc_sql
samba-tool spn add MSSQLSvc/VULNCORP-DB01 svc_sql
echo "[+] SPNs registered on svc_erp & svc_sql (Kerberoastable)"

# 6. Vulnerability 5: SYSVOL GPP cPassword
echo "[*] Planting GPP cPassword in SYSVOL..."
GPP_DIR="/var/lib/samba/sysvol/vulncorp.local/Policies/{D86A75A3-9F9C-4D2A-98C3-6056B481078D}/Machine/Preferences/Groups"
mkdir -p "$GPP_DIR"

cat > "$GPP_DIR/Groups.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!-- VulnCorp Legacy Group Policy Preference Deployment -->
<!-- FLAG: VULN{gpp_p4ssw0rd_l34k} -->
<Groups clsid="{3125E937-EB16-4b4c-9934-544FC6D24D26}">
  <Group clsid="{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}" name="Local Admins Policy" image="2" changed="2026-08-10 14:22:00" uid="{A37E3166-70DE-4E10-9E11-37E740924976}">
    <Properties action="U" newName="" groupName="Administrators" description="Emergency Domain Recovery Account">
      <Members>
        <Member name="backdoor" action="ADD">
          <!-- Password decrypts to: backdoor (AES-256 with MS published key) -->
          <Properties cpassword="VZBQoGpDMEUESqPnEFTqMg==" userName="backdoor" fullName="Emergency Recovery" description="Flag: VULN{gpp_p4ssw0rd_l34k}"/>
        </Member>
      </Members>
    </Properties>
  </Group>
</Groups>
EOF
chmod -R 777 /var/lib/samba/sysvol

# 7. Configure Weak SSH
echo "[*] Configuring SSH..."
mkdir -p /var/run/sshd
cat > /etc/ssh/sshd_config << 'EOF'
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 10
UsePAM yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# 8. Create local Linux mirror accounts for SSH / direct access
useradd -m -s /bin/bash john.doe 2>/dev/null || true
echo "john.doe:Corp@Admin2024" | chpasswd
usermod -aG sudo john.doe 2>/dev/null || true

useradd -m -s /bin/bash helpdesk 2>/dev/null || true
echo "helpdesk:Helpdesk@123" | chpasswd

useradd -m -s /bin/bash svc_backup 2>/dev/null || true
echo "svc_backup:Backup@Svc2024" | chpasswd

echo "root:Corp@Admin2024" | chpasswd

echo "[+] AD DC setup completed successfully!"
