terraform {
  cloud {

    organization = "PortfolioWebPage"

    workspaces {
      name = "prd_webpage_infra"
    }
  }
}
