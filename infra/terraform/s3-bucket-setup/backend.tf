terraform {
  backend "remote" {
    organization = "PortfolioWebPage"

    workspaces {
      name = "portfolio_setup"
    }
  }
}
