from decimal import Decimal
from .models import UserCustomPricing, ZipCodePricing

def calculate_item_price(user, location, product):
    """
    Executes the enterprise pricing cascade strategy for a given context:
    1. Pre-negotiated Company Contract Tier
    2. Regional Location ZIP Code Grid Match
    3. Global Catalog Baseline MSRP Fallback
    """
    # 1. Tier 1: Check for a direct corporate custom contract contract
    if user.company:
        custom_tier = UserCustomPricing.objects.filter(
            company=user.company, 
            product=product
        ).first()
        if custom_tier:
            return custom_tier.custom_price

    # 2. Tier 2: Check for a regional location ZIP code override
    if location and location.zip_code:
        regional_tier = ZipCodePricing.objects.filter(
            zip_code=location.zip_code, 
            product=product
        ).first()
        if regional_tier:
            return regional_tier.regional_price

    # 3. Tier 3: Default fallback to the baseline product catalog price
    return product.base_price