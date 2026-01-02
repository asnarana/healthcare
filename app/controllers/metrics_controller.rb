# metrics controller
# exposes prometheus metrics endpoint
class MetricsController < ApplicationController
  def index
    # Prometheus middleware handles this, but we need a route
    render plain: "# Prometheus metrics endpoint\n", status: :ok
  end
end

