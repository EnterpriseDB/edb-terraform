resource "random_id" "apply" {
  byte_length = 4
}

resource "time_static" "first_created" {
}

resource "random_pet" "name" {
}
