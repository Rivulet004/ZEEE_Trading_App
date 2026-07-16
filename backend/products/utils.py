from decimal import Decimal
from .models import UserCustomPricing, ZipCodePricing

def calculate_item_price(user, location, product, zip_code=None):
    """
    Executes the enterprise pricing cascade strategy for a given context:
    1. Pre-negotiated Company Contract Tier
    2. Regional Location ZIP Code Grid Match
    3. Global Catalog Baseline MSRP Fallback
    """
    # 1. Tier 1: Check for a direct corporate custom contract
    if user and user.is_authenticated and hasattr(user, 'company') and user.company:
        custom_tier = UserCustomPricing.objects.filter(
            company=user.company, 
            product=product
        ).first()
        if custom_tier:
            return custom_tier.negotiated_price
    # 2. Tier 2: Check for a regional location ZIP code override
    target_zip = zip_code
    if location and location.zip_code:
        target_zip = location.zip_code
    if target_zip:
        regional_tier = ZipCodePricing.objects.filter(
            zip_code=target_zip, 
            product=product
        ).first()
        if regional_tier:
            return regional_tier.regional_price
    # 3. Tier 3: Default fallback to the baseline product catalog price
    return product.base_price


def get_delivery_schedule(zip_code, current_dt=None):
    """
    Scans forward from current_dt to compute the next valid delivery date 
    and returns scheduled weekdays and daily cut-offs for a ZIP code.
    """
    import datetime
    from .models import ZipCodeRouteRule
    if current_dt is None:
        current_dt = datetime.datetime.now()
    # Query specific ZIP route rule, fallback to standard Monday to Friday, 4 PM cutoff
    rule = ZipCodeRouteRule.objects.filter(zip_code=zip_code.strip().upper()).first()
    if rule:
        days_list = [int(d) for d in rule.delivery_days.split(',') if d.strip()]
        cutoff_time = rule.cutoff_time
    else:
        days_list = [1, 2, 3, 4, 5]  # Monday to Friday
        cutoff_time = datetime.time(16, 0, 0)  # 4:00 PM
    today_weekday = current_dt.isoweekday()  # 1=Monday, 7=Sunday
    today_time = current_dt.time()
    # Determine scanning start day
    scan_dt = current_dt
    if today_weekday in days_list and today_time >= cutoff_time:
        # past cutoff today, shift start of scheduling to tomorrow
        scan_dt += datetime.timedelta(days=1)
    # Find the next available delivery day
    for i in range(14):
        if scan_dt.isoweekday() in days_list:
            break
        scan_dt += datetime.timedelta(days=1)
    return {
        "zip_code": zip_code,
        "delivery_days": days_list,
        "cutoff_time": cutoff_time.strftime("%H:%M:%S"),
        "next_available_date": scan_dt.date().isoformat()
    }