resource "null_resource" "chmod_user_script" {
  provisioner "local-exec" {
    command = "chmod +x ./scripts/tools/get_user.sh"
  }

  triggers = {
    always_run = timestamp()
  }
}

data "external" "current_user" {
  program     = ["bash", "./scripts/tools/get_user.sh"]
  depends_on  = [null_resource.chmod_user_script]
}

output "logged_in_user" {
  value = data.external.current_user.result["user"]
}

