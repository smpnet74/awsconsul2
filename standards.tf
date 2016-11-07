variable "ami_standard" {
	default = "ami-2051294a"
}

variable "consul_servers" {
    default = "1"
    description = "The number of Consul servers to launch."
}