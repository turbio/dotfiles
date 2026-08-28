# prometheus pushgateway — stage-1 duplicate of the host instance; cutover
# (prometheus scrape + pushers retarget, host service removal) happens
# separately once this is confirmed. stateless: metrics are in-memory by
# design, lost on restart, same as the host version.
{ ... }:
{
  services.prometheus.pushgateway = {
    enable = true;
    web.listen-address = "0.0.0.0:9091";
  };
}
