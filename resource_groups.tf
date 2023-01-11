resource "aws_resourcegroups_group" "prod_servers" {
  name = "prod_servers"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::EC2::Instance"
  ],
  "TagFilters": [
    {
      "Key": "uuid",
      "Values": ["hiAhBT4ym9xShmtEzxC21z"]
    }
  ]
}
JSON
  }
}
