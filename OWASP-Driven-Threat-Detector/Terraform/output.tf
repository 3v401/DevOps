output "scanner_private_ip" {
    value = aws_instance.my_scanner_EC2_instance.private_ip
}

output "builder_private_ip" {
    value = aws_instance.my_builder_EC2_instance.private_ip
}

output "monitoring_private_ip" {
    value = aws_instance.my_monitoring_EC2_instance.private_ip
}

output "api_public_ip" {
    value = aws_instance.my_api_EC2_instance.public_ip
}

output "bastion_public_ip" {
    value = aws_instance.my_bastion_EC2_instance.public_ip
}

data "template_file" "prometheus_config" {
    template = file("${path.module}/prometheus.yml.tpl")
    vars = {
        API_IP                  = aws_instance.my_api_EC2_instance.private_ip
        SCANNER_IP              = aws_instance.my_scanner_EC2_instance.private_ip
        JENKINS_IP              = aws_instance.my_jenkins_EC2_instance.private_ip
        BUILDER_IP              = aws_instance.my_builder_EC2_instance.private_ip
    }
}

resource "local_file" "prometheus_config" {
    content                     = data.template_file.prometheus_config.rendered
    filename                    = "${path.module}/prometheus.yml"
}