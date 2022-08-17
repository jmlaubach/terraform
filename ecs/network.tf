# Fetch AZs in the current region
data "aws_availability_zones" "available" {
}

resource "aws_vpc" "main-vpc" {
  cidr_block = "10.10.0.0/16"
}

# Create var.az_count private subnets, each in a different AZ
resource "aws_subnet" "private-sub" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main-vpc.id
}

# Create var.az_count public subnets, each in a different AZ
resource "aws_subnet" "public-sub" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.main-vpc.cidr_block, 8, var.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.main-vpc.id
  map_public_ip_on_launch = true
}

# Create an Internet Gateway 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main-vpc.id
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.main-vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Create a NAT gateway with an Elastic IP for each private subnet to get internet connectivity
resource "aws_eip" "eip" {
  count      = var.az_count
  vpc        = true
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "gw" {
  count         = var.az_count
  subnet_id     = element(aws_subnet.public-sub.*.id, count.index)
  allocation_id = element(aws_eip.eip.*.id, count.index)
}

# Create a Route Table for the private subnets to the NAT Gateway.
resource "aws_route_table" "private-route" {
  count  = var.az_count
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.gw.*.id, count.index)
  }
}

# Explicitly associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.private-sub.*.id, count.index)
  route_table_id = element(aws_route_table.private-route.*.id, count.index)
}