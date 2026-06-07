packer {
  required_plugins {
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = ">= 1.0.0"
    }
  }
}

source "virtualbox-iso" "ubuntu" {
  vm_name       = "ubuntu-security-lab"
  guest_os_type = "Ubuntu_64"

  # Use Ubuntu 24.04 Server ISO for stable autoinstall
  iso_url      = "C:/Users/smile/Downloads/ubuntu-26.04-live-server-amd64.iso"
  iso_checksum = "none"

  cpus      = 4
  memory    = 8192
  disk_size = 81920

  headless = false

  http_directory = "http"

  ssh_username = "packer"
  ssh_password = "packer"
  ssh_host     = "127.0.0.1"
  ssh_port     = 2222
  ssh_timeout  = "120m"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--natpf1", "guestssh,tcp,,2222,,22"]
  ]

  boot_wait = "30s"

boot_command = [
  "e<wait>",
  "<down><down><down>",
  "<end>",
  " autoinstall ds=nocloud\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---",
  "<f10>"
]

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  guest_additions_mode = "disable"
}

build {
  name    = "ubuntu-security-lab"
  sources = ["source.virtualbox-iso.ubuntu"]

  provisioner "file" {
    source      = "scripts/provisioning_script.sh"
    destination = "/tmp/provisioning_script.sh"
  }

  provisioner "shell" {
    inline = [
      "whoami",
      "groups",
      "sudo -n whoami",
      "chmod +x /tmp/provisioning_script.sh",
      "sudo -n bash -x /tmp/provisioning_script.sh"
    ]
  }
}
