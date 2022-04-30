output "control_plane_ip" {
  value = digitalocean_droplet.control_plane.*.ipv4_address
}

output "worker_ip" {
  value = digitalocean_droplet.worker.*.ipv4_address
}

#output "cluster_context" {
#  value       = format("ktew-%s-%s", random_string.lower.result, var.dc_region)
#  description = "kubectl config use-context --context ..."
#}
