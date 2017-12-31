defmodule CryptoScannerWeb.PageController do
  use CryptoScannerWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
