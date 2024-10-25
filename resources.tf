resource "yandex_compute_instance" "vm" {
  count       = 2
  name        = "vm${count.index}"
  platform_id = "standard-v1"
  zone        = var.zone

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size = 8
    }
  }
  resources {
    core_fraction = 5
    cores  = 2
    memory = 2
  }
  network_interface {
    subnet_id      = "e2lhu6omt75nnfnsh4nr"
    nat            = true
  }

  metadata = {
    user-data = "${file("./meta.yml")}"
  }
  scheduling_policy {
    preemptible = true
  }
}

resource "yandex_lb_target_group" "vm-group" {
  name = "vm-group"
  target {
    subnet_id = "e2lhu6omt75nnfnsh4nr"
    address = yandex_compute_instance.vm[0].network_interface.0.ip_address
  }
  target {
    subnet_id = "e2lhu6omt75nnfnsh4nr"
    address = yandex_compute_instance.vm[1].network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb-1" {
  name = "lb-1"
  deletion_protection = "false"
  listener {
    name = "listener-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.vm-group.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

data "template_file" "inventory" {
  template = templatefile("./terraform/templates/inventory.tpl", {
    user      = "ansible"
    host_name = yandex_compute_instance.vm.*.name,
    host_addr = yandex_compute_instance.vm.*.network_interface.0.nat_ip_address
  })
}

resource "local_file" "save_inventory" {
  content  = data.template_file.inventory.rendered
  filename = "./ansible/inventory"
}

