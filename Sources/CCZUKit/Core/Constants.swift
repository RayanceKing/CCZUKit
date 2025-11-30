import Foundation

/// API常量
public enum CCZUConstants {
    public static let rootSSOLogin = "https://sso.cczu.edu.cn/lyuapServer/login"
    public static let rootVPNURL = "https://vpn.cczu.edu.cn"
    public static let wechatAppAPI = "http://jwqywx.cczu.edu.cn"
    
    public static let defaultHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"
    ]
}
