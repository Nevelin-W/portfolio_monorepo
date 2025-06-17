terraform {
  cloud {

    organization = "PortfolioWebPage"

    workspaces {
      name = "dev_webpage_infra"
    }
  }
}
