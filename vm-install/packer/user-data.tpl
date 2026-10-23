#cloud-config
users:
  - default
  - name: ubuntu
    gecos: Ubuntu User
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    shell: /bin/bash
    lock_passwd: true

runcmd:
  - echo "Waiting for DNS to become available..."
  - until nslookup raw.githubusercontent.com; do sleep 2; done
  - mkdir -p /opt/opsmx
  - cd /opt/opsmx
  - echo "current pwd..."
  - pwd
  - echo "RELEASETAG=${RELEASETAG}"
  - curl -fSL -o bundle-lite.sh "https://raw.githubusercontent.com/OpsMx/enterprise-ssd/${RELEASETAG}/vm-install/image-setup/bundle-lite.sh"
  - curl -fSL -o version.env "https://raw.githubusercontent.com/OpsMx/enterprise-ssd/${RELEASETAG}/vm-install/image-setup/version.env"
  - chmod +x bundle-lite.sh
  - sed -i "s/^RELEASETAG=.*/RELEASETAG=${RELEASETAG}/" version.env
  - mkdir -p /opt/opsmx/images
  - mount -t 9p -o trans=virtio,version=9p2000.L,cache=loose,access=any host_images /opt/opsmx/images
  - mkdir -p /opt/opsmx/temp-images
  - rsync -avh --progress /opt/opsmx/images/ /opt/opsmx/temp-images/
  - ./bundle-lite.sh
  - sudo docker images
  - rm -f bundle-lite.sh version.env
  - sudo cloud-init clean
  - sudo shutdown -h now
