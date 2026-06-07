packer {
  required_plugins {
    virtualbox = {
      source  = "github.com/hashicorp/virtualbox"
      version = ">= 1.0.0"
    }
  }
}

source "virtualbox-iso" "ubuntu" {
  vm_name       = "ubuntu-26-04-local-vm"
  guest_os_type = "Ubuntu_64"

  iso_url      = "C:/Users/smile/Downloads/ubuntu-26.04-live-server-amd64.iso"
  iso_checksum = "none"

  cpus      = 4
  memory    = 8192
  disk_size = 81920

  headless = false

  http_directory = "http"

  ssh_username = "packer"
  ssh_password = "packer"
  ssh_timeout  = "90m"

  boot_wait = "20s"

boot_command = [
  "<esc><wait>",
  "c<wait>",
  "linux /casper/vmlinuz autoinstall ds=nocloud\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<enter>",
  "initrd /casper/initrd<enter>",
  "boot<enter>"
]

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  guest_additions_mode = "disable"
}

build {
  name    = "ubuntu-26-04-local-vm"
  sources = ["source.virtualbox-iso.ubuntu"]

  provisioner "file" {
    source      = "scripts/provisioning_script.sh"
    destination = "/tmp/provisioning_script.sh"
  }

  provisioner "shell" {
  inline = [
    "sudo -n whoami",
    "chmod +x /tmp/provisioning_script.sh",
    "sudo -n bash /tmp/provisioning_script.sh"
  ]
}
}