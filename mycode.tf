provider "aws" {
  region  = "ap-south-1"
  profile = "samar"
}












resource "aws_security_group" "sg_http_ssh" {
  name        = "sg_http_ssh"
  description = "Access to inbound traffic"


  ingress {
    description = "HTTP support"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH support"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my sg"
  }
}












resource "tls_private_key" "mykey1" {
  algorithm   = "RSA"
}


resource "aws_key_pair" "key_access" {
  key_name   = "mykey"
  public_key =  tls_private_key.mykey1.public_key_openssh


  depends_on = [
    tls_private_key.mykey1
  ]

  tags = {
    Name = "access key"
  }
}












resource "aws_instance" "my_instance" {
  ami               = "ami-0447a12f28fddb066"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name          = aws_key_pair.key_access.key_name
  security_groups   = [ "${aws_security_group.sg_http_ssh.name}" ]


  provisioner "remote-exec" {
    connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykey1.private_key_pem
    host     = aws_instance.my_instance.public_ip
  }


    inline = [
      "sudo yum install httpd git php -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }



  tags = {
    Name = "myos"
  }
}











resource "aws_ebs_volume" "ebs_vol" {
  availability_zone = aws_instance.my_instance.availability_zone
  size              = 1

  tags = {
    Name = "ebs_vol"
  }
}

resource "aws_volume_attachment" "ebs_vol_attach" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.ebs_vol.id
  instance_id  = aws_instance.my_instance.id
  force_detach = true

  depends_on = [
    aws_ebs_volume.ebs_vol
  ]
}











resource "null_resource" "nullremote1"  {


depends_on = [
    aws_volume_attachment.ebs_vol_attach,
  ]




  connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykey1.private_key_pem
    host     = aws_instance.my_instance.public_ip
  }


  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone  https://github.com/Samarps/task1.git  /var/www/html/",
      "sudo rm -rf /var/www/html*.jpg  /var/www/html*.png  /var/www/html*.jpeg",
    ]
  
  }

}











resource "aws_s3_bucket" "mybucket" {
  bucket = "samar3199bucket"
  acl    = "public-read"

  versioning {
  enabled = true
  }

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}











resource "aws_s3_bucket_object" "my_object" {
  bucket = "samar3199bucket"
  key    = "image.png"
  source = "https://raw.githubusercontent.com/Samarps/task1/master/image.png"

  depends_on = [
    null_resource.nullremote1,
  ]
}












resource "aws_cloudfront_distribution" "cf_s3" {
  origin {
    domain_name = aws_s3_bucket.mybucket.bucket_regional_domain_name
    origin_id   = "S3-samar3199bucket"

    
        custom_origin_config {
            http_port  = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
       
    enabled = true




    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-samar3199bucket"


        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
 
    restrictions {
        geo_restriction {
           
            restriction_type = "none"
        }
    }


    viewer_certificate {
        cloudfront_default_certificate = true


    }
}












resource "aws_ebs_snapshot" "example_snapshot" {
  volume_id = aws_ebs_volume.ebs_vol.id

depends_on = [
    aws_cloudfront_distribution.cf_s3,
  ]

  tags = {
    Name = "my snapshot"
  }
}











resource "null_resource" "nulllocal2"  {


depends_on = [
    null_resource.nullremote1,
  ]


  provisioner "local-exec" {
    command = "start chrome  ${aws_instance.my_instance.public_ip}"
  }
}


