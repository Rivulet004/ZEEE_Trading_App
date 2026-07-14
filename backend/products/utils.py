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