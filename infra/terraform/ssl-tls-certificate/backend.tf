terraform {
  backend "remote" {
    organization = "PortfolioWebPage"

    workspaces {
      name = "ssl-tls-cerificate"
    }
  }
}
