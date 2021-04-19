// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.4.25 < 0.8.5;

import "../client/node_modules/@openzeppelin/contracts/token/ERC777/ERC777.sol";
interface FlowOracleInterface {
    function getFlow(uint _webindex) external view returns(uint,uint,address);
    function getSubFlow(uint _webindex,string memory _language) external view returns(uint,uint);
}
interface SubtitleApplyInterface {
    function checkApply(uint _webindex) external view returns(bool);
    function getLanguage(uint _webindex)external view returns(uint,string[] memory);
    function checkApplyLa(uint _webindex,string memory _language)external view returns(bool);
    function returnRewardInfo(uint _webindex,string memory _language)external view returns(uint,uint,address,address[] memory);
}
contract VideoToken is ERC777 {
    address CEO;
    address Wallet;
    uint videoproportion;
    uint fbproportion;
    uint interval;
    uint totalpaytoken;
    event videoTokenReceived(address videowner,uint number);
    event subTokenReceived(address videowner,uint number,uint fbnumber);
    constructor(address[] memory defaultOperators,address payable wallet,uint initialSupply,uint _interval,uint _videoproportion,uint _fbproportion,address _oracleaddress,address _subtitleaddress) ERC777("VideoToken", "VT", defaultOperators,wallet,initialSupply)
    {   
          Wallet = wallet;
          CEO = msg.sender;
          videoproportion = _videoproportion;
          fbproportion = _fbproportion;
          interval = _interval;
          FlowOracle = FlowOracleInterface(_oracleaddress);
          SubtitleApply = SubtitleApplyInterface(_subtitleaddress);
    }

    FlowOracleInterface FlowOracle;
    SubtitleApplyInterface SubtitleApply;
    struct VideoRecord {
        bool create;
        uint lastflow;
        uint lastgettime;
        uint lastgettoken;
        uint totalgettoken;
        mapping(string => subRecord) subrecords;
    } 
    struct subRecord {
        bool pay1success;
        uint sublastflow;
        //type 1.
        bool create;
        uint surplus;
    }
    mapping(uint => VideoRecord) videosReward;
    
    
    
    function getReward(uint _webindex) public {
    require(block.timestamp >= videosReward[_webindex].lastgettime + interval); 
        uint newvideoflow;
        address videowner;
        bool applyif;
        uint applynum;
        uint totalvideotoken;
        uint gettoken;
        (,newvideoflow,videowner) = FlowOracle.getFlow(_webindex); 
        (applyif) = SubtitleApply.checkApply(_webindex); 
        totalvideotoken = (newvideoflow - videosReward[_webindex].lastflow)*10**(18-videoproportion);
        burnreward(Wallet,totalvideotoken);
        if (applyif == false){
            gettoken = totalvideotoken;
            reward(videowner,gettoken);
            videosReward[_webindex].lastgettoken = gettoken;
            videosReward[_webindex].totalgettoken += gettoken;
            emit videoTokenReceived(videowner, gettoken);
        }else{     
           totalpaytoken = 0; 
           string[] memory applyla;
           (applynum,applyla) = SubtitleApply.getLanguage(_webindex);
            reward(videowner,10);
            uint id;
           for (id = 0;id < applynum;id ++) {
                loopGet(_webindex, applyla[id]);
           }
            if (totalvideotoken > totalpaytoken) {
                gettoken = totalvideotoken - totalpaytoken;
                reward(videowner,gettoken);
                videosReward[_webindex].lastgettoken = gettoken;
                videosReward[_webindex].totalgettoken += gettoken;
                emit videoTokenReceived(videowner, gettoken);
            }
        } 
        videosReward[_webindex].lastflow = newvideoflow;
        videosReward[_webindex].lastgettime = block.timestamp;
    }
    
    function loopGet(uint _webindex,string memory _language) public {
           uint paytype;
           uint paynumber;
           uint newsubflow;
           address subowner;
           address[] memory fbaddress;
           uint subtokens;
           uint fbtokens;
           uint totalsubtoken;
           uint totalfbtoken;
           bool ifsuccess;
           (ifsuccess) = SubtitleApply.checkApplyLa(_webindex,_language);
           if (ifsuccess == true) {
                  (paytype,paynumber,subowner,fbaddress) = SubtitleApply.returnRewardInfo(_webindex,_language);
                  (,newsubflow) = FlowOracle.getSubFlow(_webindex, _language);
                  totalsubtoken = (newsubflow - videosReward[_webindex].subrecords[_language].sublastflow)*10**(18-videoproportion);
                  videosReward[_webindex].subrecords[_language].sublastflow = newsubflow;
                  if (paytype == 0) {
                      subtokens = totalsubtoken/(10**paynumber);
                      totalfbtoken = subtokens/(10**fbproportion);
                      fbtokens = totalfbtoken/fbaddress.length;
                      totalpaytoken += subtokens;
                      reward(subowner,subtokens-totalfbtoken);
                      for(uint fbid=0;fbid<fbaddress.length;fbid++){
                         reward(fbaddress[fbid],fbtokens);
                      }
                  }else if(paytype == 1) {
                           if (videosReward[_webindex].subrecords[_language].create == false) {
                           videosReward[_webindex].subrecords[_language].surplus = paynumber;
                           videosReward[_webindex].subrecords[_language].create = true;
                           }
                           if (videosReward[_webindex].subrecords[_language].pay1success == false) {       
                               if(totalsubtoken >= videosReward[_webindex].subrecords[_language].surplus) {    
                                  subtokens = videosReward[_webindex].subrecords[_language].surplus;
                                  videosReward[_webindex].subrecords[_language].surplus = 0;
                                  videosReward[_webindex].subrecords[_language].pay1success = true;
                                }else {
                                  subtokens = totalsubtoken;
                                  videosReward[_webindex].subrecords[_language].surplus = videosReward[_webindex].subrecords[_language].surplus - subtokens;
                                }       
                                totalfbtoken = subtokens/(10**fbproportion);
                                fbtokens = totalfbtoken/fbaddress.length;
                                totalpaytoken += subtokens;
                                reward(subowner,subtokens-totalfbtoken);
                                for(uint fbid=0;fbid<fbaddress.length;fbid++){
                                    reward(fbaddress[fbid],fbtokens);
                                }              
                            }
                    }
                    emit subTokenReceived(subowner,subtokens-totalfbtoken,fbtokens);
                } 
    }
 

}
