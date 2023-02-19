terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.48.0"
    }
    github = {
      source = "integrations/github"
      version = "5.12.0"
    }
  }
}
provider "aws" {
    region = "us-east-1"
    profile = "write-here-your-aws-profile"
}

provider "github" {
    token = "XXXXXXXXXXXXXX"
}

resource "github_repository" "bookstore" {
    name = "bookstore-api"
    visibility = "private"
    auto_init = true # otomatik olarak README.md dosyası oluşturarak pull/push için hazır hale getirme amaçlı
}

resource "github_branch_default" "main" {
    branch = "main"
    repository = github_repository.bookstore.name
}

variable "files" {
    default = ["bookstore-api.py", "docker-compose.yml", "Dockerfile", "requirements.txt"]
}

resource "github_repository_file" "repo_files" {
    for_each = toset(var.files) #files içindeki her bir dosya için ayrı ayrı uygulanması için
    content = file(each.value)
    file = each.value
    repository = github_repository.bookstore.name
    commit_message = "clear"
    overwrite_on_create = true  
}

resource "aws_instance" "bookstore" {
    key_name = "write-here-your-keyname"
    ami = "ami-0b5eea76982371e91"
    instance_type = "t2.micro"
    security_groups = ["bookstore-SG"]

    user_data = <<-EOF
        #! /bin/bash
        yum update -y
        amazon-linux-extras install docker -y
        systemctl start docker
        systemctl enable docker
        usermod -a -G docker ec2-user 
        curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /user/local/bin/docker-compose

        mkdir -p /home/ec2-user/bookstore-api
        cd /home/ec2-user/bookstore-api

        TOKEN="XXXXXXXXXXXXXXX"
        FOLDER="https://$TOKEN@raw.githubusercontent.com/MucahitCrn/bookstore-api/main/"

        curl -s -o bookstore-api.py -L "$FOLDER"bookstore-api.py
        curl -s -o Dockerfile -L "$FOLDER"Dockerfile
        curl -s -o docker-compose.yml -L "$FOLDER"docker-compose.yml
        curl -s -o requirements.txt -L "$FOLDER"requirements.txt

        docker build -dit bookstore-api:latest .
        docker-compose up -d
    EOF
  
    depends_on = [github_repository.bookstore, github_repository_file.repo_files]
}


resource "aws_security_group" "bookstore-SG" {
    name = "bookstore-SG"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }


    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"  # all 
        cidr_blocks = ["0.0.0.0/0"]
    }
}


output "Public_Ip" {
   value =  "http://${aws_instance.bookstore.public_dns}"
}