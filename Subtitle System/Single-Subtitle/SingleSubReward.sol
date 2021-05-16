// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.4.25 < 0.8.5;
import "../../MutleSubtitle/ERC777/ERC777.sol";
interface FlowOracleInterface {
    function getFlow(uint _webindex) external view returns(uint,uint,address);
    function getSubFlow(uint _webindex) external view returns(uint,uint);
}
interface SubtitleApplyInterface {
    function checkApply(uint _webindex) external view returns(bool,bool);
    function returnRewardInfo(uint _webindex)external view returns(uint,uint,address,address[] memory);
    function returnRewardInfo(uint _webindex,string memory _language)external view returns(uint,uint,address,address[] memory);
    function returnSTPrice(uint _subtitleindex) external view returns(uint,address);
}
contract VideoToken is ERC777 {
    address CEO;
    address Wallet;
    address subtitleapplyaddr;
    uint totalpaytoken;
    uint videoproportion;
    uint fbproportion;
    uint interval;
    mapping(uint => VideoRecord) videosReward;
    mapping(uint => bool) sell;
    mapping(uint => address) sellST;
    event videoTokenReceived(address videowner,uint number);
    event subTokenReceived(address videowner,uint number,uint fbnumber);
    event buySTsucess(uint STindex,address STowner,address STnewowner);
    
    constructor(address[] memory defaultOperators,address payable wallet,uint initialSupply,uint _interval,uint _videoproportion,uint _fbproportion,address _oracleaddress,address _subtitleaddress) ERC777("VideoToken", "VT", defaultOperators,wallet,initialSupply)
    {   
          Wallet = wallet;
          CEO = msg.sender;
          videoproportion = _videoproportion;
          fbproportion = _fbproportion;
          interval = _interval;
          FlowOracle = FlowOracleInterface(_oracleaddress);
          SubtitleApply = SubtitleApplyInterface(_subtitleaddress);
          subtitleapplyaddr = _subtitleaddress;
    }

    FlowOracleInterface FlowOracle;
    SubtitleApplyInterface SubtitleApply;
    struct VideoRecord {
        uint lastflow;
        uint lastgettime;
        uint lastgettoken;
        uint totalgettoken;
       
        bool pay1success;
        uint sublastflow;
        //type 1.
        bool subcreate;
        uint surplus;
    } 
    //ST购买相关.
    //返回ST是否售卖信息.
    function buyInfo(uint _STindex)external view returns(bool,address) {
       return (sell[_STindex],sellST[_STindex]);
    }
   
    function buyST(uint _STindex)public returns(bool){
        require(sell[_STindex] == false);
        uint price;
        address STowner;
        (price,STowner) = SubtitleApply.returnSTPrice(_STindex);
        if(price > 0) {
           bool result = transfer(STowner,price);
           if(result == true) {
               sellST[_STindex] = msg.sender;
               sell[_STindex] = true;
               emit buySTsucess(_STindex,STowner,msg.sender);
               return true;
           }
        }
        return false;
    }
    function resetBuyInfo(uint _STindex)external {
        require(msg.sender == subtitleapplyaddr);
        sell[_STindex] = false;
        sellST[_STindex] = address(0);
    }

    function getReward(uint _webindex) public {
        require(block.timestamp >= videosReward[_webindex].lastgettime + interval); 
        uint newvideoflow;
        address videowner;
        bool ifsuccess;
        uint gettoken;
        uint totalvideotokens;
        (,newvideoflow,videowner) = FlowOracle.getFlow(_webindex); 
        (,ifsuccess) = SubtitleApply.checkApply(_webindex); 
        totalvideotokens = (newvideoflow - videosReward[_webindex].lastflow)*10**(18-videoproportion);
        burnreward(Wallet,totalvideotokens);
        if (ifsuccess == false) {
            gettoken = totalvideotokens;
            reward(videowner,gettoken);
            videosReward[_webindex].lastgettoken = gettoken;
            videosReward[_webindex].totalgettoken += gettoken;
            emit videoTokenReceived(videowner, gettoken);
        }else {
           totalpaytoken = 0; 
           supportGet(_webindex,totalvideotokens);
        }
        if (totalvideotokens > totalpaytoken) {
                gettoken = totalvideotokens - totalpaytoken;
                reward(videowner,gettoken);
                videosReward[_webindex].lastgettoken = gettoken;
                videosReward[_webindex].totalgettoken += gettoken;
                emit videoTokenReceived(videowner, gettoken);
        }
        videosReward[_webindex].lastflow = newvideoflow;
        videosReward[_webindex].lastgettime = block.timestamp;
    } 
    function supportGet(uint _webindex,uint totalvideotokens) internal {
           uint paytype;
           uint paynumber;
           address subowner;
           address[] memory fbaddress;
           uint newsubflow;
           uint subtokens;
           uint fbtokens;
           uint totalsubtokens;
           uint totalfbtokens;
           (paytype,paynumber,subowner,fbaddress) = SubtitleApply.returnRewardInfo(_webindex);
           (,newsubflow) = FlowOracle.getSubFlow(_webindex);
           totalsubtokens = (newsubflow - videosReward[_webindex].sublastflow)*10**(18-videoproportion);
           videosReward[_webindex].sublastflow = newsubflow;
           if (paytype == 0) {
               subtokens = totalsubtokens/(10**paynumber);
               totalfbtokens = subtokens/(10**fbproportion);
               fbtokens = totalfbtokens/fbaddress.length;
               reward(subowner,subtokens-totalfbtokens);
               totalpaytoken += subtokens;
               for(uint fbid = 0;fbid < fbaddress.length;fbid ++){
                   reward(fbaddress[fbid],fbtokens);
               }
            }else if(paytype == 1) {
                if (videosReward[_webindex].subcreate == false) {
                    videosReward[_webindex].surplus = paynumber*10**18;
                    videosReward[_webindex].subcreate = true;
                }
                if (videosReward[_webindex].pay1success == false) {       
                    if(totalvideotokens >= videosReward[_webindex].surplus) {
                       subtokens = videosReward[_webindex].surplus;
                       videosReward[_webindex].surplus = 0;
                       videosReward[_webindex].pay1success = true;
                    }else{
                        subtokens = totalvideotokens;
                        videosReward[_webindex].surplus = videosReward[_webindex].surplus - totalvideotokens;
                    }
                totalpaytoken += subtokens;    
                totalfbtokens = subtokens/(10**fbproportion);
                fbtokens = totalfbtokens/fbaddress.length;
                reward(subowner,subtokens-totalfbtokens);
                for(uint fbid = 0;fbid < fbaddress.length;fbid ++){
                    reward(fbaddress[fbid],fbtokens);
                }
                }                     
            }
            emit subTokenReceived(subowner,subtokens-totalfbtokens,fbtokens);
    }
}
