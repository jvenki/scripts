while getopts ":d:s:o:" opt; do
    case $opt in
        s) src_dir="$OPTARG"
        ;;
        d) for_date="$OPTARG"
        ;;
        o) out_dir="$OPTARG"
        ;;
    esac
done

declare in_dir="${out_dir}/${for_date}/in"
declare out_dir="${out_dir}/${for_date}/out"
declare experiment_id="ex338";
declare -a files_to_be_parsed=("LoanDukaan.log" "localhost_access.log" "clickstream.log")
declare -a treatments=("t1" "t2" "t3");

declare ignore_url_patterns='GET /personal-loan|POST /personal-loan|GET /car-loan|POST /car-loan|GET /used-car-loan|POST /used-car-loan|GET /home-loan|POST /home-loan|GET /debit-card|POST /debit-card|GET /savings-account|POST /savings-account|POST /saveLead.html|GET /credit-score|GET /.*credit-report|GET /no-credit-report.html|GET /creditReportFromToken.html|POST /credit_tracker|GET /ct-.*|POST /ct-.*|POST /.*credit-report.*|GET /credit-report-status.html|GET /websocket/creditTracker|GET / HTTP/1.1|GET /struts/domTT.js|GET /saveGeoLocation.html|GET /myaccount.html|GET /verifyWorkEmail.html|GET /gzip_|POST /sendCode.html|POST /verifyCode.html|GET /.*getHeaderAjax.html|GET /getAppsFlyerLinkParams.html|GET .*/queried-options.html|GET .*/autoComplete.html|POST .*/recommend.html|GET /recommended-options.html|GET /myaccount_ajax.html|POST /ajax-login-status.html|GET /getNativeLoginWidget.html|POST /signin_iframe.html|GET /privacy-policy.html|POST /signup_iframe.html|POST /short_signup_iframe_json.html|GET /getLatestMobileNumber.html|POST /forgotpwd_iframe.html|GET /recent-searches.html|GET /help-centre.html|POST /credit-card/create_app_event_for_geolocator.html|POST /credit-card/sendCode.html|GET /credit-card/mobilePixel.html|POST /credit-card/verifyCode.html|GET /checkMatch.html|POST /credit-card/sendPANNotification.html|GET /credit-card/congratulations.html|GET /setEventDetails.html|GET /signin_social.html|GET /.*/preLoadImages.html|GET /credit-card/get-dynamic-offers.html|GET /credit-card/subscribeToNewsLetterMC.html|GET /credit-card/verifyOwnershipForm.html|GET /credit-card/.*-credit-card.html|GET /credit-card/load-elig-slides.html|POST /credit-card/offer-details-compare.html|POST /credit-card/document_types.html|POST /credit-card/clear_and_load_next_form.html|POST /credit-card/load_next_form_app.html|POST /credit-card/file_upload.html|GET /credit-card/credit-card/fetchShortlistedOffers.html|POST /credit-card/getCityState.html|GET /credit-card/application_view.html|POST /credit-card/verifyOwnership.html|GET /credit-card/application_scrape.html|POST /credit-card/remove_file.html|POST /credit-card/triggerAutoSubmit.html|POST /credit-card/checkApprovalStatus.html|POST /credit-card/application_dpCheck.html|POST /credit-card/load-prefill-data.html|POST /credit-card/ajax-offer-details-mobile.html'

declare replace_url_patterns='
s/"GET \/credit-card.html.*"/LP/g; 
s/"GET \/credit-card-smart-landing.html.*"/SL_LANDING/g; 
s/"GET \/.*credit-card.html?variant=slide.*"/REG_SLIDE/g; 
s/"GET \/credit-card\/search-offers.html.*"/SEARCH_OFFERS_G/g; 
s/"POST \/credit-card\/search-offers.html.*"/SEARCH_OFFERS_P/g; 
s/"GET \/credit-card\/search.html.*"/SEARCH/g; 
s/"POST \/credit-card\/post-eligibility-details.html.*"/POST_ELIG/g; 
s/"GET \/credit-card\/zero-offers.html.*"/ZERO_OFFERS/g; 
s/"GET \/credit-card\/get-more-offers.html.*"/MORE_OFFERS/g; 
s/"GET \/credit-card\/newCompleteEligibility.html.*"/COMPLETE_ELIG/g; 
s/"GET \/credit-card\/showBaseMPAjaxElig.html.*"/SHOW_BASE_ELIG/g; 
s/"POST \/credit-card\/eligibility-submit.html.*"/ELIG_SUBMIT/g; 
s/"GET \/credit-card\/offers-with-searchId.html.*"/OFFERS_WITH_SEARCH_ID/g; 
s/"POST \/credit-card\/preapproved_offers_available.html.*"/PAPQ/g; 
s/"GET \/credit-card\/offer-details.html.*"/OFFER_DETAILS/g; 
s/"GET \/credit-card\/card-details.html.*"/CARD_DETAILS/g; 
s/"GET \/credit-card\/application_create.html.*"/APP_CREATE/g; 
s/"GET \/credit-card\/application_edit.html.*"/APP_EDIT/g; 
s/"POST \/credit-card\/application_save.html.*"/APP_SAVE/g; 
s/"POST \/credit-card\/application_submit.html.*"/APP_SUBMIT/g; 
s/"GET \/credit-card\/dpReRunOffers.html.*"/DP_CHECK/g; 
s/"POST \/credit-card\/create-lead-before-search.html.*"/CREATE_LEAD_BEFORE_SEARCH/g; 
s/"POST \/ajax-content.html.*"/INIT_SESSION/g; 
s/"POST \/.*\/ajax-content.html.*"/INIT_SESSION2/g; 
'

function print_progress() {
    completed_ops_count="$1"
    total_ops_count="$2"
    msg="$3"
    perc_completed=$((completed_ops_count*100/total_ops_count))
    printf "$msg: Completed: % -101s(%s%%)\r" $(head -c $perc_completed < /dev/zero | tr '\0' '#') $perc_completed;
}

function initialize() {
    echo "Initializing the runtime"
    if [ ! -d "$in_dir" ]; then
        echo "    Creating the IN directory $in_dir"
        mkdir -p "$in_dir"

        progress_msg="        Copying relevant files"
        number_of_containers=$(ls $src_dir | grep B.* | wc -l)
        total_ops_count=$((${#files_to_be_parsed[@]}*2*number_of_containers))
        i=0
        print_progress $i $total_ops_count "$progress_msg" 
        for cntr_dir in $src_dir/B*; do
            container_name=$(basename ${cntr_dir})
            for fn in ${files_to_be_parsed[@]}; do
                if [ -f ${src_dir}/${container_name}/DAS/tomcat/logs/${fn}.${for_date}.gz ]; then
                    cp ${src_dir}/${container_name}/DAS/tomcat/logs/${fn}.${for_date}.gz ${in_dir}/${fn}.${for_date}.${container_name}.gz
                    print_progress $((++i)) $total_ops_count "$progress_msg" 
                    gunzip ${in_dir}/${fn}.${for_date}.${container_name}.gz
                    print_progress $((++i)) $total_ops_count "$progress_msg" 
                else
                    i=$((i+2))
                    print_progress $i $total_ops_count "$progress_msg" 
                fi
            done
        done
        printf "\n"
    fi

    if [ ! -d "$out_dir" ]; then
        echo "    Creating the OUT directory $out_dir"
        mkdir -p "$out_dir"
    fi
}

function parse_session_ids_which_got_CC_SL() {
    echo "Searching for the SL SMS access patterns in clickstream.log files..."
    grep "credit-card-smart-landing.*smsCampaign=true" $in_dir/clickstream.log.* \
        | awk '{
            split($0, tokens, ""); 
            ip_address = tokens[2];
            session_id = tokens[4];
            user_agent = tokens[9];
            user_agent_family = "Unknown";
            if (match(user_agent, /Android.*Version\/[.0-9]*.*Mobile Safari\/[.0-9]*/)) {
                user_agent_family = "AndroidWebview";
            } else if (match(user_agent, /Android.*Chrome\/[.0-9]* Mobile/)) {
                user_agent_family = "ChromeAndroidMobile";;
            } else if (match(user_agent, /Android.*Chrome\/[.0-9]*/) && !(user_agent ~ "Mobile") ) {
                user_agent_family = "ChromeAndroidTablet";;
            } else if (match(user_agent, /Windows NT.*Chrome\/[.0-9]*/)) {
                user_agent_family = "ChromeWindowsDesktop";;
            } else if (match(user_agent, /Macintosh; Intel Mac OS X .* AppleWebKit\/[.0-9]* .* Chrome\/[.0-9]* Safari\/[.0-9]*/)) {
                user_agent_family = "ChromeMac";
            } else if (match(user_agent, /Linux x86_64.*Chrome\/[.0-9]*/)) {
                user_agent_family = "ChromeLinux";
            } else if (match(user_agent, /\(iPhone; CPU iPhone OS .*\) AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Mobile\/[A-Z0-9a-z]* Safari\/[.0-9]*/)) {    
                user_agent_family = "SafariiPhone"
            } else if (match(user_agent, /\(Macintosh.*\) AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Safari\/[.0-9]*/)) {    
                user_agent_family = "SafariMac"
            } else if (match(user_agent, /Mozilla\/5.0 \(X11; Ubuntu; Linux i686; rv:24.0\) Gecko\/20100101 Firefox\/24.0/)) {
                user_agent_family = "FirefoxBlacklisted";
            } else if (match(user_agent, /\(Android [.0-9]*; Mobile; rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]*/)) {
                user_agent_family = "FirefoxAndroidMobile)";
            } else if (match(user_agent, /\(Mobile; .*Android; rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]* KAIOS\/[.0-9]*/)) {
                user_agent_family = "FirefoxKAIOS";
            } else if (match(user_agent, /\(Windows NT [.0-9]*; .*rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]*/)) {
                user_agent_family = "FirefoxWindowsDesktop";
            } else if (match(user_agent, /Android.*AppleWebKit\/[.0-9]* .* Mobile Safari\/[.0-9]*/) || match(user_agent, /Android.*AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Safari\/[.0-9]*/)) {
                user_agent_family = "AndroidBrowser";
            } else if (match(user_agent, /^Opera.*/)) {
                user_agent_family = "Opera";
            } else if (match(user_agent, /MSIE .* Trident/)) {
                user_agent_family = "InternetExplorer";
            } else if (match(user_agent, /UCBrowser\/[.0-9]* U3\/[.0-9]* Mobile Safari\/[.0-9]*/) || match(user_agent, /^UCWEB\/2.0.*UCBrowser\/[.0-9]*/)) {
                user_agent_family = "UCBrowser";
            } else if (match(user_agent, /SamsungBrowser\/[.0-9]* Mobile Safari\/[.0-9]*/)) {
                user_agent_family = "SamsungBrowser";
            } else if (match(user_agent, /OppoBrowser/)) {
                user_agent_family = "OppoBrowser";
            } else if (match(user_agent, /^okhttp\/[.0-9]*$/)) {
                user_agent_family = "BB-App";
            } else if (match(user_agent, /^Dalvik.*/)) {
                user_agent_family = "Dalvik";
            } else if (match(user_agent, /^Apache-HttpClient\/UNAVAILABLE.*/)) {
                user_agent_family = "ApacheHTTPClient";
            } else if (match(user_agent, /^Mozilla\/5.0 \(BB10; Touch\)/) || match(user_agent, /^Mozilla\/5.0 \(BB10; Kbd\)/)) {
                user_agent_family = "BlackBerry";
            } else if (match(user_agent, /^facebookexternalhit\/1.1/)) {
                user_agent_family = "FacebookCrawler";
            } else if (match(user_agent, /SimpleScraper/)) {
                user_agent_family = "SimpleScraper";
            }
            print session_id "\t" ip_address "\t" user_agent_family "\t" "\""user_agent"\""
        }' \
        > $out_dir/tmp_clickstream_sl_alone.txt

    echo "Computing the SessionIDs which opened CC SL SMSCampaign..."
    sort $out_dir/tmp_clickstream_sl_alone.txt | uniq > "$out_dir"/session_id_to_ua_including_blacklisted.txt
    grep -v "FirefoxBlacklisted" $out_dir/session_id_to_ua_including_blacklisted.txt > "$out_dir"/session_id_to_ua.txt
    awk '{print $1}' "$out_dir"/session_id_to_ua.txt > "$out_dir"/session_ids.txt
}

function categorize_sessions_based_on_treatments() {
    number_of_chunks=$(split --verbose -l 3000 -d --additional-suffix .txt $out_dir/session_ids.txt tmp_session_ids-chunk- | wc -l)
    total_ops_count=$((number_of_chunks+1+${#treatments[@]}))
    mv tmp_session_ids-chunk-* $out_dir/.

    i=0
    progress_msg="Categorizing the sessions based on assigned treatments"
    print_progress $i $total_ops_count "$progress_msg" 
    for chunk in "$out_dir"/tmp_session_ids-chunk-*.txt; do
        ./agrep -f $chunk $in_dir/LoanDukaan.log.* \
            | grep "The CAMPAIGN_KEY session attribute modified to .*${experiment_id}t*" \
            | sed -e "s/The CAMPAIGN_KEY session attribute modified to //g;" \
            | awk -v experiment_id="$experiment_id" '{gsub(".*"experiment_id, "", $8); print $3 " " $8}' \
            | sort | uniq | awk '{print $1 "\t" $2}' \
            >> "$out_dir"/tmp_session_ids_categorization_1.txt

        print_progress $((++i)) $total_ops_count "$progress_msg" 
    done

    join $out_dir/session_id_to_ua.txt $out_dir/tmp_session_ids_categorization_1.txt > $out_dir/tmp_session_ids_categorization_2.txt
    print_progress $((++i)) $total_ops_count "$progress_msg" 
    for treatment in "${treatments[@]}"; do
        grep ".*${treatment}$" $out_dir/tmp_session_ids_categorization_2.txt | sort > "$out_dir"/session_ids-"$treatment".txt
        print_progress $((++i)) $total_ops_count "$progress_msg" 
    done

    printf "\n"
    rm "$out_dir"/tmp_session_ids-chunk-*.txt "$out_dir"/tmp_session_ids_categorization*
}

function compute_session_activity() {
    rm -f "$out_dir"/session_activity-*.txt

    i=0
    total_ops_count=$((${#treatments[@]}*2))
    progress_msg="Computing the Session Activity"
    print_progress $i $total_ops_count "$progress_msg" 
    for treatment in "${treatments[@]}"; do
        awk '{print $1}' "$out_dir"/session_ids-"$treatment".txt > "$out_dir"/tmp_session_ids_only-"$treatment".txt
        ./agrep -f "$out_dir"/tmp_session_ids_only-"$treatment".txt $in_dir/localhost_access.log.* > "$out_dir"/localhost_access-"$treatment".txt
        print_progress $((++i)) $total_ops_count "$progress_msg" 

        cat -n "$out_dir"/localhost_access-"$treatment".txt \
            | awk 'BEGIN{ OFS="\t" }{print $13, $1, $6"]", $8 " " $9 " " $10, $11}' \
            | sort -k1,1 -k2,2n \
            | awk 'BEGIN{ FS=OFS="\t" }{print $1, $3, $4, $5}' \
            > "$out_dir"/tmp_localhost_access-"$treatment".txt

        #join -1 1 -2 1 -t $'\t' $out_dir/session_id_to_ua.txt "$out_dir"/tmp_localhost_access-"$treatment".txt > "$out_dir"/tmp_localhost_access-"$treatment"-2.txt
        join -1 1 -2 1 -t $'\t' $out_dir/session_id_to_ua.txt "$out_dir"/tmp_localhost_access-"$treatment".txt > "$out_dir"/localhost_access-"$treatment".txt
        rm "$out_dir"/tmp_localhost_access-"$treatment".txt

        grep -Ev "$ignore_url_patterns" "$out_dir"/localhost_access-"$treatment".txt | sed "$replace_url_patterns" \
            | awk 'BEGIN{ FS=OFS="\t" }{
                if (NR == 0) {
                    last_session_id = ""
                    aggr_activity = ""
                    last_session_info = ""
                }
                curr_session_id = $1;
                if (last_session_id == "" || curr_session_id == last_session_id) {
                    aggr_activity = aggr_activity $6 ",";
                } else if (last_session_id != "" && curr_session_id != last_session_id) {
                    print last_session_info, aggr_activity;
                    aggr_activity = $6 ",";
                }
                last_session_id = curr_session_id;
                last_session_info = $1 "\t" $2 "\t" $3 "\t" $4 "\t"
            } END {print last_session_info, aggr_activity}' \
            >> "$out_dir"/session_activity-"$treatment".txt
        print_progress $((++i)) $total_ops_count "$progress_msg" 
    done
    printf "\n"
}

function print_summary() {
    echo ""
    echo "*************************************************************************************************************"
    echo ""
    echo "Summary of SL accesses"
    echo "Number of Unique Sessions = " `cat ${out_dir}/session_ids-t1.txt ${out_dir}/session_ids-t2.txt ${out_dir}/session_ids-t3.txt | wc -l`
    echo ""
    printf "%10s %15s %15s %20s %5s %20s %20s\n" "Treatment" "Sessions#" "SLAccess#" "SlideshowRendered#" "%" "DirectToSearch#" "WrongZeroOffersInT3"
    for treatment in "${treatments[@]}"; do
        number_of_unique_sessions=$(cat "$out_dir"/session_ids-"$treatment".txt | wc -l)
        number_of_sl_accesses=$(grep "GET \/credit-card-smart-landing.*" "$out_dir"/localhost_access-$treatment.txt | wc -l)
        number_of_slideshow_renders=$(grep "GET \/credit-card-smart-landing.*200$" "$out_dir"/localhost_access-$treatment.txt | wc -l)
        number_of_direct_to_search=$(grep "GET \/credit-card-smart-landing.*302$" "$out_dir"/localhost_access-$treatment.txt | wc -l)
        wrong_zero_offers_in_t3=0

        if [ $treatment = "t3" ]; then
            number_of_slideshow_renders=$(grep -Eo "SL_LANDING(,INIT_SESSION2)?,CREATE_LEAD_BEFORE_SEARCH" "$out_dir"/session_activity-t3.txt | wc -l)
            number_of_direct_to_search=$(grep -Eo "SL_LANDING(,INIT_SESSION2)?(,POST_ELIG)?,SEARCH" "$out_dir"/session_activity-t3.txt | wc -l)
            wrong_zero_offers_in_t3=$(grep -Eo "SL_LANDING(,INIT_SESSION2)?(,POST_ELIG)?,SEARCH,ZERO_OFFERS" "$out_dir"/session_activity-t3.txt | wc -l)
        fi
        perc_of_renders=$((number_of_slideshow_renders*100/(number_of_slideshow_renders+number_of_direct_to_search)))

        printf "%10s %15s %15s %20s %5s %20s %20s\n" $treatment $number_of_unique_sessions $number_of_sl_accesses $number_of_slideshow_renders $perc_of_renders $number_of_direct_to_search $wrong_zero_offers_in_t3
    done
}

start_time=$(($(date +%s%N)/1000000))

initialize
parse_session_ids_which_got_CC_SL
categorize_sessions_based_on_treatments
compute_session_activity
print_summary

end_time=$(($(date +%s%N)/1000000))
echo ""
echo "Total Time Taken = " $((end_time-start_time)) "ms"