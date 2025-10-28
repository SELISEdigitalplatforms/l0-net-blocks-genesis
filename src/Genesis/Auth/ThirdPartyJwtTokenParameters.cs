﻿
namespace Blocks.Genesis
{
    public class ThirdPartyJwtTokenParameters
    {
        public string ProviderName { get; set; } = string.Empty;
        public string Issuer { get; set; } = string.Empty;
        public string Subject { get; set; } = string.Empty;
        public List<string> Audiences { get; set; } = [];
        public string PublicCertificatePath { get; set; } = string.Empty;
        public string JwksUrl { get; set; } = string.Empty;
        public string PublicCertificatePassword { get; set; } = string.Empty;
        public string CookieKey { get; set; } = string.Empty;
    }
}
