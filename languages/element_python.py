"""
🧪 نظام ربط العناصر الكيميائية باللغات البرمجية
AtomicLanguages System - By Ramdan09a
"""

# ============ Python (Py) ============
# محاكاة الحسابات الكيميائية والفيزيائية

import numpy as np
from dataclasses import dataclass
from typing import List, Dict

@dataclass
class Element:
    """عنصر كيميائي"""
    symbol: str
    name: str
    atomic_number: int
    atomic_mass: float
    language: str
    description: str

class ChemicalSimulator:
    """محاكاة الحسابات الكيميائية باستخدام Python"""
    
    def __init__(self):
        self.elements = []
    
    def calculate_molecular_weight(self, formula: Dict[str, int]) -> float:
        """حساب الوزن الجزيئي"""
        total_weight = 0
        for element_symbol, count in formula.items():
            element = self.get_element(element_symbol)
            total_weight += element.atomic_mass * count
        return total_weight
    
    def get_element(self, symbol: str) -> Element:
        """البحث عن عنصر"""
        for element in self.elements:
            if element.symbol == symbol:
                return element
        raise ValueError(f"العنصر {symbol} غير موجود")
    
    def add_element(self, element: Element):
        """إضافة عنصر جديد"""
        self.elements.append(element)
    
    def simulate_reaction(self, reactants: Dict[str, float], 
                         products: Dict[str, float]) -> Dict:
        """محاكاة تفاعل كيميائي"""
        reactant_mass = sum(self.get_element(e).atomic_mass * count 
                           for e, count in reactants.items())
        product_mass = sum(self.get_element(e).atomic_mass * count 
                          for e, count in products.items())
        
        return {
            "reactants_mass": reactant_mass,
            "products_mass": product_mass,
            "mass_balance": abs(reactant_mass - product_mass) < 0.001,
            "efficiency": (product_mass / reactant_mass) * 100 if reactant_mass > 0 else 0
        }

# مثال على الاستخدام
def main():
    simulator = ChemicalSimulator()
    
    # إضافة العناصر
    py_element = Element(
        symbol="Py",
        name="Python",
        atomic_number=1,
        atomic_mass=3.14,
        language="Python",
        description="لغة برمجية قوية للحسابات العلمية"
    )
    
    simulator.add_element(py_element)
    
    # حساب الوزن الجزيئي
    formula = {"Py": 2}
    weight = simulator.calculate_molecular_weight(formula)
    print(f"✅ الوزن الجزيئي: {weight}")
    
    # محاكاة تفاعل
    reaction = simulator.simulate_reaction(
        {"Py": 1},
        {"Py": 1}
    )
    print(f"✅ نتيجة التفاعل: {reaction}")

if __name__ == "__main__":
    main()
