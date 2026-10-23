packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "release_tag" {
  type    = string
  default = "ami_image_creation_v1"
}

variable "iso_url" {
  type    = string
}

variable "iso_checksum" {
  type    = string
}

variable "memory" {
  type    = string
  default = "26624"
}

variable "cpu_cores" {
  type    = string
  default = "12"
}

locals {
  image_name = "ubuntu-ssd"
}



source "qemu" "ubuntu_prebake" {
  iso_url            = var.iso_url
  iso_checksum       = var.iso_checksum
  output_directory   = "output-qcow2"
  format             = "qcow2"
  accelerator        = "none"
  vm_name            = local.image_name
  communicator       = "none"
  #ssh_username       = "ubuntu"
  #ssh_password       = "ubuntu"
  #ssh_host           = "127.0.0.1"
  #host_port_min    = 2222         # force it to use this
  #host_port_max    = 2222         # and only this
  #ssh_port           = 2222
  #ssh_wait_timeout   = "5m"
  disk_size          = 65536
  headless           = true
  disk_image         = true
  shutdown_timeout = "120m"

  floppy_label = "cidata"
  floppy_files = [
	"user-data",
	"meta-data",
	"network-config"]
  
  qemuargs = [
    ["-m", "${var.memory}M"],
    ["-smp", var.cpu_cores],
    ["-netdev", "user,id=net0,hostfwd=tcp::2222-:22"],
    ["-device", "virtio-net,netdev=net0"],
    ["-virtfs", "local,path=./images,mount_tag=host_images,security_model=none,id=images"],
    ["-serial", "file:build-console.log"]
  ]
}

build {
  name    = "ubuntu-prebake-build"
  sources = ["source.qemu.ubuntu_prebake"]

  post-processor "shell-local" {
    inline = [
      "echo 'Converting QCOW2 to VMDK...'",
      "qemu-img convert -O vmdk output-qcow2/${local.image_name} ${local.image_name}.vmdk",

      "echo 'Creating OVF descriptor...'",
      "cat > ${local.image_name}.ovf <<EOF",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<ovf:Envelope xmlns:ovf=\"http://schemas.dmtf.org/ovf/envelope/1\">",
      "  <ovf:References>",
      "    <ovf:File ovf:id=\"file1\" ovf:href=\"${local.image_name}.vmdk\" ovf:size=\"$(stat -c%s ${local.image_name}.vmdk)\"/>",
      "  </ovf:References>",
      "  <ovf:DiskSection>",
      "    <ovf:Disk ovf:diskId=\"disk1\" ovf:fileRef=\"file1\" ovf:capacity=\"4294967296\"/>",
      "  </ovf:DiskSection>",
      "  <ovf:VirtualSystem ovf:id=\"${local.image_name}\">",
      "    <ovf:Name>${local.image_name}</ovf:Name>",
      "  </ovf:VirtualSystem>",
      "</ovf:Envelope>",
      "EOF",

      "echo 'Creating OVA...'",
      "tar -cvf ${local.image_name}.ova ${local.image_name}.ovf ${local.image_name}.vmdk",
      "echo '✅ OVA generation complete: ${local.image_name}.ova'"
    ]
  }
}

