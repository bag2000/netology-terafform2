terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = ""
  cloud_id  = ""
  folder_id = ""
  zone = "ru-central1-a"
}

resource "yandex_compute_instance" "server" {
  count = 2
  name = "terraform${count.index}"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8ps4vdhf5hhuj8obp2"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.subnet-1.id}"
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.network-1.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_lb_target_group" "target-group-1" {
  name      = "my-target-group"
  #region_id = "ru-central1-a"

  target {
    subnet_id = "${yandex_vpc_subnet.subnet-1.id}"
    address   = "${yandex_compute_instance.server[0].network_interface.0.ip_address}"
  }

  target {
    subnet_id = "${yandex_vpc_subnet.subnet-1.id}"
    address   = "${yandex_compute_instance.server[1].network_interface.0.ip_address}"
  }
}

resource "yandex_lb_network_load_balancer" "balancer" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_lb_target_group.target-group-1.id}"

    healthcheck {
      name = "tcp"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}


output "internal_ip_address_server_0" {
  value = yandex_compute_instance.server[0].network_interface.0.ip_address
}
output "external_ip_address_server_0" {
  value = yandex_compute_instance.server[0].network_interface.0.nat_ip_address
}

output "internal_ip_address_server_1" {
  value = yandex_compute_instance.server[1].network_interface.0.ip_address
}
output "external_ip_address_server_1" {
  value = yandex_compute_instance.server[1].network_interface.0.nat_ip_address
}

output "balancer_ip_address" {
  value = yandex_lb_network_load_balancer.balancer.listener.*
}
