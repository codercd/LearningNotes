//
//  ViewController.swift
//  NetWork
//
//  Created by LiChendi on 16/6/22.
//  Copyright © 2016年 LiChendi. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Alamofire
import SwiftyJSON
import RxDataSources


class ViewController: UIViewController {

    @IBOutlet weak var repositoryName: UITextField!
    @IBOutlet weak var searchResult: UITableView!
    
    
    
    var bag: DisposeBag! = DisposeBag()
    
    typealias SectionTableModel = SectionModel<String, RepositoryModel>
    let dataSource = RxTableViewSectionedReloadDataSource<SectionTableModel>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.searchResult.rxDidSelectRowAtIndexPath.subscribeNext { tableview,indexpath in
            tableview.deselectRowAtIndexPath(indexpath, animated: true)
        }.addDisposableTo(self.bag)
        
        self.dataSource.configureCell = {(_, tv, indexPath, element) in
            let cell = tv.dequeueReusableCellWithIdentifier("RepositoryInfoCell", forIndexPath: indexPath) as! RepositoryInfoTableViewCell
            cell.name.text = element.name
            cell.detail.text = element.detail
            
            return cell
        }
        // Do any additional setup after loading the view, typically from a nib.
        
        self.repositoryName.rx_text
            .filter {
                return $0.characters.count > 2
            }
            .throttle(0.5, scheduler: MainScheduler.instance)
            .flatMap {
                self.searchForGithub($0)
            }
            .subscribe(onNext: {respositoryModelArray in
                self.searchResult.dataSource = nil
//                    typealias O = Observable<[RepositoryModel]>
//                    typealias CC = (Int, RepositoryModel, RepositoryInfoTableViewCell) -> Void
//                
//                    let binder: O -> CC -> Disposable = self.searchResult.rx_itemsWithCellIdentifier("RepositoryInfoCell", cellType: RepositoryInfoTableViewCell.self)
//                
//                    let currentArgument = {(rowIndex: Int,element: RepositoryModel, cell: RepositoryInfoTableViewCell) in
//                        cell.name.text = element.name
//                        cell.detail.text = element.detail
//                    }
//                
//                    Observable.just(respositoryModelArray)
//                        .bindTo(binder, curriedArgument: currentArgument)
//                        .addDisposableTo(self.bag)
                
                Observable.just(self.createGithubSectionModel(respositoryModelArray))
                    .bindTo(self.searchResult.rx_itemsWithDataSource(self.dataSource))
                    .addDisposableTo(self.bag)
            }, onError: { error in
                self.displayErrorAlert(error as NSError)
            })
            .addDisposableTo(self.bag)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController {
    
    private func createGithubSectionModel(repoInfo: [RepositoryModel]) -> [SectionTableModel] {
        var ret:[SectionTableModel] = []
        var items: [RepositoryModel] = []
        if repoInfo.count < 10 {
            ret.append(SectionTableModel(model: "TOP 1 - 10", items: repoInfo))
        }else {
            for i in 1...repoInfo.count {
                items.append(repoInfo[i - 1])
                let isSectionBreak = i / 10 != 0 && i % 10 == 0
                if isSectionBreak {
                    ret.append(SectionTableModel(model: "Top \(i  - 9) - \(i)", items: items))
                    items = []
                }
                
            }
        }
        return ret
    }
    
    private func searchForGithub(repositoryName: String) -> Observable<[RepositoryModel]> {
        return Observable.create {
            (observer: AnyObserver<[RepositoryModel]>) -> Disposable in
            
            let url = "https://api.github.com/search/repositories"
            let parameters = [
                "q": repositoryName + " stars:>=2000"
            ]
            
            let request = Alamofire.request(.GET, url,
                parameters: parameters, encoding: .URLEncodedInURL)
                .responseJSON { response in
                    switch response.result {
                    case .Success(let json):
                        let info = self.parseGithubResponse(json)
                        
                        observer.on(.Next(info))
                        observer.on(.Completed)
                    case .Failure(let error):
                        observer.on(.Error(error))
                    }
            }
            
            return AnonymousDisposable {
                request.cancel()
            }
        }
    }
    
    private func parseGithubResponse(response: AnyObject) -> [RepositoryModel] {
        let json = JSON(response);
        let totalCount = json["total_count"].int!
        var ret: [RepositoryModel] = []
        
        if totalCount != 0 {
            let items = json["items"]
            
            for (_, subJson):(String, JSON) in items {
                let fullName = subJson["full_name"].stringValue
                let description = subJson["description"].stringValue
                let htmlUrl = subJson["html_url"].stringValue
                let avatarUrl = subJson["owner"]["avatar_url"].stringValue
                
                ret.append(RepositoryModel(
                    name: fullName,
                    detail:
                    description,
                    htmlUrl: htmlUrl,
                    avatar: avatarUrl))
            }
        }
        
        return ret
    }
    
    private func displayErrorAlert(error: NSError) {
        let alert = UIAlertController(title: "Network error",
                                      message: error.localizedDescription,
                                      preferredStyle: .Alert)
        
        alert.addAction(UIAlertAction(title: "OK",
            style: UIAlertActionStyle.Default,
            handler: nil))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
}