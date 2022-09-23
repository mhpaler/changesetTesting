const nextTranslate = require('next-translate');
const withTM = require("next-transpile-modules")(["@mikepaler/ui"]);

/**
 * @type {import('next').NextConfig}
 **/
 const nextConfig = {
  reactStrictMode: true,
};

module.exports = nextTranslate(withTM(nextConfig));
