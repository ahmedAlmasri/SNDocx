

//import Zippy
import Foundation
import Zippy
public class SNDocx:NSObject{
 private let wordName = "document.xml"
 public static let shared = SNDocx()
    private override init() {
        super.init()
    }
    
  public func getText(fileUrl url:URL)->String?{
    var result:String?  = nil
        do {
            let files = try ZipFile.init(url: url)
            
            for file in files {
                
                if file.contains(wordName){
                   result =  parseDocx(files[file])
                    break
                }
            }
            
        }catch {
            debugPrint(error.localizedDescription)
        }
       
        return result
    }
    
    
    
    private func parseDocx(_ data:Data?)->String?{
        guard let data = data else {
            return nil
        }
        let str = String.init(data: data, encoding: .utf8)
        
        return matches(str ?? "")
    }
    
    
    private func matches(_ originalText:String)->String{
    var result = [String]()
    var re: NSRegularExpression!
    do {
    re = try NSRegularExpression(pattern: "<w:t.*?>(.*?)<\\/w:t>", options: [])
    } catch {
    
    }
    
    let matches = re.matches(in: originalText, options: [], range: NSRange(location: 0, length: originalText.utf16.count))
    
        for match in matches {
            
            result.append((originalText as NSString).substring(with: match.range(at: 1)))
        }
        return result.joined(separator: "\n")
    }
}
