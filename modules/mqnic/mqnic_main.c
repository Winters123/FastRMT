/*

Copyright 2019, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

#include "mqnic.h"
#include <linux/module.h>
#include <linux/pci-aspm.h>
#include <linux/delay.h>

MODULE_DESCRIPTION("mqnic driver");
MODULE_AUTHOR("Alex Forencich");
MODULE_LICENSE("Dual MIT/GPL");
MODULE_VERSION(DRIVER_VERSION);
MODULE_SUPPORTED_DEVICE(DRIVER_NAME);

static const struct pci_device_id pci_ids[] = {
    { PCI_DEVICE(0x1234, 0x1001) },
    { PCI_DEVICE(0x5543, 0x1001) },
    { 0 /* end */ }
};

MODULE_DEVICE_TABLE(pci, pci_ids);

void mqnic_i2c_set_scl(void *data, int state)
{
    struct mqnic_i2c_priv *priv = data;

    if (state)
    {
        iowrite32(ioread32(priv->scl_out_reg) | priv->scl_out_mask, priv->scl_out_reg);
    }
    else
    {
        iowrite32(ioread32(priv->scl_out_reg) & ~priv->scl_out_mask, priv->scl_out_reg);
    }
    ioread32(priv->scl_out_reg);
}

void mqnic_i2c_set_sda(void *data, int state)
{
    struct mqnic_i2c_priv *priv = data;

    if (state)
    {
        iowrite32(ioread32(priv->sda_out_reg) | priv->sda_out_mask, priv->sda_out_reg);
    }
    else
    {
        iowrite32(ioread32(priv->sda_out_reg) & ~priv->sda_out_mask, priv->sda_out_reg);
    }
    ioread32(priv->sda_out_reg);
}

int mqnic_i2c_get_scl(void *data)
{
    struct mqnic_i2c_priv *priv = data;

    return !!(ioread32(priv->scl_in_reg) & priv->scl_in_mask);
}

int mqnic_i2c_get_sda(void *data)
{
    struct mqnic_i2c_priv *priv = data;

    return !!(ioread32(priv->sda_in_reg) & priv->sda_in_mask);
}

static const struct i2c_algo_bit_data mqnic_i2c_algo = {
    .setsda     = mqnic_i2c_set_sda,
    .setscl     = mqnic_i2c_set_scl,
    .getsda     = mqnic_i2c_get_sda,
    .getscl     = mqnic_i2c_get_scl,
    .udelay     = 5,
    .timeout    = 20
};

static struct i2c_board_info mqnic_eeprom_info = {
    I2C_BOARD_INFO("24c02", 0x50),
};

static int mqnic_init_i2c(struct mqnic_dev *mqnic)
{
    int ret = 0;
    // interface i2c interfaces
    // TODO

    // eeprom i2c interface
    mqnic->eeprom_i2c_adap.owner = THIS_MODULE;
    mqnic->eeprom_i2c_priv.mqnic = mqnic;
    mqnic->eeprom_i2c_priv.scl_in_reg = mqnic->hw_addr+MQNIC_REG_GPIO_IN;
    mqnic->eeprom_i2c_priv.scl_out_reg = mqnic->hw_addr+MQNIC_REG_GPIO_OUT;
    mqnic->eeprom_i2c_priv.sda_in_reg = mqnic->hw_addr+MQNIC_REG_GPIO_IN;
    mqnic->eeprom_i2c_priv.sda_out_reg = mqnic->hw_addr+MQNIC_REG_GPIO_OUT;
    mqnic->eeprom_i2c_priv.scl_in_mask = 1 << 24;
    mqnic->eeprom_i2c_priv.scl_out_mask = 1 << 24;
    mqnic->eeprom_i2c_priv.sda_in_mask = 1 << 25;
    mqnic->eeprom_i2c_priv.sda_out_mask = 1 << 25;
    mqnic->eeprom_i2c_algo = mqnic_i2c_algo;
    mqnic->eeprom_i2c_algo.data = &mqnic->eeprom_i2c_priv;
    mqnic->eeprom_i2c_adap.algo_data = &mqnic->eeprom_i2c_algo;
    mqnic->eeprom_i2c_adap.dev.parent = &mqnic->pdev->dev;
    iowrite32(ioread32(mqnic->hw_addr+MQNIC_REG_GPIO_OUT) & ~(1 << 26), mqnic->hw_addr+MQNIC_REG_GPIO_OUT); // WP disable
    strlcpy(mqnic->eeprom_i2c_adap.name, "mqnic EEPROM", sizeof(mqnic->eeprom_i2c_adap.name));
    ret = i2c_bit_add_bus(&mqnic->eeprom_i2c_adap);
    if (ret)
    {
        return ret;
    }

    mqnic->eeprom_i2c_client = i2c_new_device(&mqnic->eeprom_i2c_adap, &mqnic_eeprom_info);
    if (mqnic->eeprom_i2c_client == NULL)
    {
        ret = -ENODEV;
    }

    return ret;
}

static void mqnic_remove_i2c(struct mqnic_dev *mqnic)
{
    // eeprom i2c interface
    if (mqnic->eeprom_i2c_client)
    {
        i2c_unregister_device(mqnic->eeprom_i2c_client);
        mqnic->eeprom_i2c_client = NULL;
    }

    if (mqnic->eeprom_i2c_adap.owner)
    {
        i2c_del_adapter(&mqnic->eeprom_i2c_adap);
    }

    memset(&mqnic->eeprom_i2c_adap, 0, sizeof(mqnic->eeprom_i2c_adap));
}

static LIST_HEAD(mqnic_devices);
static DEFINE_SPINLOCK(mqnic_devices_lock);

static unsigned int mqnic_get_free_id(void)
{
    struct mqnic_dev *mqnic;
    unsigned int id = 0;
    bool available = false;

    while (!available)
    {
        available = true;
        list_for_each_entry(mqnic, &mqnic_devices, dev_list_node)
        {
            if (mqnic->id == id)
            {
                available = false;
                id++;
                break;
            }
        }
    }

    return id;
}

struct mqnic_dev *mqnic_find_by_minor(unsigned minor)
{
    struct mqnic_dev *mqnic;

    spin_lock(&mqnic_devices_lock);

    list_for_each_entry(mqnic, &mqnic_devices, dev_list_node)
        if (mqnic->misc_dev.minor == minor)
            goto done;

    mqnic = NULL;

done:
    spin_unlock(&mqnic_devices_lock);

    return mqnic;
}

static int mqnic_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
    int ret = 0;
    struct mqnic_dev *mqnic;
    struct device *dev = &pdev->dev;

    int k = 0;

    dev_info(dev, "mqnic probe");

    if (!(mqnic = devm_kzalloc(dev, sizeof(*mqnic), GFP_KERNEL)))
    {
        return -ENOMEM;
    }

    mqnic->pdev = pdev;
    pci_set_drvdata(pdev, mqnic);

    mqnic->misc_dev.minor = MISC_DYNAMIC_MINOR;

    // assign ID and add to list
    spin_lock(&mqnic_devices_lock);
    mqnic->id = mqnic_get_free_id();
    list_add_tail(&mqnic->dev_list_node, &mqnic_devices);
    spin_unlock(&mqnic_devices_lock);

    snprintf(mqnic->name, sizeof(mqnic->name), DRIVER_NAME "%d", mqnic->id);

    // Disable ASPM
    pci_disable_link_state(pdev, PCIE_LINK_STATE_L0S | PCIE_LINK_STATE_L1 | PCIE_LINK_STATE_CLKPM);

    // Enable device
    ret = pci_enable_device_mem(pdev);
    if (ret)
    {
        dev_err(dev, "Failed to enable PCI device");
        goto fail_enable_device;
    }

    // Set mask
    ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(64));
    if (ret)
    {
        dev_warn(dev, "Warning: failed to set 64 bit PCI DMA mask");
        ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(32));
        if (ret)
        {
            dev_err(dev, "Failed to set PCI DMA mask");
            goto fail_regions;
        }
    }

    // Set max segment size
    dma_set_max_seg_size(dev, DMA_BIT_MASK(32));

    // Reserve regions
    ret = pci_request_regions(pdev, DRIVER_NAME);
    if (ret)
    {
        dev_err(dev, "Failed to reserve regions");
        goto fail_regions;
    }

    mqnic->hw_regs_size = pci_resource_end(pdev, 0) - pci_resource_start(pdev, 0) + 1;
    mqnic->hw_regs_phys = pci_resource_start(pdev, 0);

    // Map BAR
    mqnic->hw_addr = pci_ioremap_bar(pdev, 0);
    if (!mqnic->hw_addr)
    {
        ret = -ENOMEM;
        dev_err(dev, "Failed to map BARs");
        goto fail_map_bars;
    }

    // Check if device needs to be reset
    if (ioread32(mqnic->hw_addr) == 0xffffffff)
    {
        ret = -EIO;
        dev_err(dev, "Deivce needs to be reset");
        goto fail_map_bars;
    }

    // Read ID registers
    mqnic->fw_id = ioread32(mqnic->hw_addr+MQNIC_REG_FW_ID);
    dev_info(dev, "FW ID: 0x%08x", mqnic->fw_id);
    mqnic->fw_ver = ioread32(mqnic->hw_addr+MQNIC_REG_FW_VER);
    dev_info(dev, "FW version: %d.%d", mqnic->fw_ver >> 16, mqnic->fw_ver & 0xffff);
    mqnic->board_id = ioread32(mqnic->hw_addr+MQNIC_REG_BOARD_ID);
    dev_info(dev, "Board ID: 0x%08x", mqnic->board_id);
    mqnic->board_ver = ioread32(mqnic->hw_addr+MQNIC_REG_BOARD_VER);
    dev_info(dev, "Board version: %d.%d", mqnic->board_ver >> 16, mqnic->board_ver & 0xffff);

    mqnic->phc_count = ioread32(mqnic->hw_addr+MQNIC_REG_PHC_COUNT);
    dev_info(dev, "PHC count: %d", mqnic->phc_count);
    mqnic->phc_offset = ioread32(mqnic->hw_addr+MQNIC_REG_PHC_OFFSET);
    dev_info(dev, "PHC offset: 0x%08x", mqnic->phc_offset);
    mqnic->phc_hw_addr = mqnic->hw_addr+mqnic->phc_offset;

    mqnic->if_count = ioread32(mqnic->hw_addr+MQNIC_REG_IF_COUNT);
    dev_info(dev, "IF count: %d", mqnic->if_count);
    mqnic->if_stride = ioread32(mqnic->hw_addr+MQNIC_REG_IF_STRIDE);
    dev_info(dev, "IF stride: 0x%08x", mqnic->if_stride);
    mqnic->if_csr_offset = ioread32(mqnic->hw_addr+MQNIC_REG_IF_CSR_OFFSET);
    dev_info(dev, "IF CSR offset: 0x%08x", mqnic->if_csr_offset);

    // Allocate MSI IRQs
    ret = pci_alloc_irq_vectors(pdev, 1, 32, PCI_IRQ_MSI);
    if (ret < 0)
    {
        dev_err(dev, "Failed to allocate IRQs");
        goto fail_map_bars;
    }

    // Set up I2C interfaces
    ret = mqnic_init_i2c(mqnic);
    if (ret)
    {
        dev_err(dev, "Failed to register I2C interfaces");
        goto fail_i2c;
    }

    // Read MAC from EEPROM
    if (mqnic->eeprom_i2c_client)
    {
        ret = i2c_smbus_read_i2c_block_data(mqnic->eeprom_i2c_client, 0x00, 6, mqnic->base_mac);
        if (ret < 0)
        {
            dev_warn(dev, "Failed to read MAC from EEPROM");
        }
    }
    else
    {
        dev_warn(dev, "Failed to read MAC from EEPROM; no EEPROM I2C client registered");
    }

    // Enable bus mastering for DMA
    pci_set_master(pdev);

    // register PHC
    if (mqnic->phc_count)
    {
        mqnic_register_phc(mqnic);
    }

    // Set up interfaces
    if (mqnic->if_count > MQNIC_MAX_IF)
        mqnic->if_count = MQNIC_MAX_IF;

    for (k = 0; k < mqnic->if_count; k++)
    {
        dev_info(dev, "Creating interface %d", k);
        ret = mqnic_init_netdev(mqnic, k, mqnic->hw_addr + k*mqnic->if_stride);
        if (ret)
        {
            dev_err(dev, "Failed to create net_device");
            goto fail_init_netdev;
        }
    }

    mqnic->misc_dev.name = mqnic->name;
    mqnic->misc_dev.fops = &mqnic_fops;

    ret = misc_register(&mqnic->misc_dev);
    if (ret)
    {
        dev_err(dev, "misc_register failed: %d\n", ret);
        goto fail_miscdev;
    }

    pci_save_state(pdev);

    // probe complete
    return 0;

    // error handling
fail_miscdev:
fail_init_netdev:
    for (k = 0; k < MQNIC_MAX_IF; k++)
    {
        if (mqnic->ndev[k])
        {
            mqnic_destroy_netdev(mqnic->ndev[k]);
        }
    }
    mqnic_unregister_phc(mqnic);
    pci_clear_master(pdev);
fail_i2c:
    mqnic_remove_i2c(mqnic);
    pci_free_irq_vectors(pdev);
fail_map_bars:
    pci_iounmap(pdev, mqnic->hw_addr);
    pci_release_regions(pdev);
fail_regions:
    pci_disable_device(pdev);
fail_enable_device:
    spin_lock(&mqnic_devices_lock);
    list_del(&mqnic->dev_list_node);
    spin_unlock(&mqnic_devices_lock);
    return ret;
}

static void mqnic_remove(struct pci_dev *pdev)
{
    struct mqnic_dev *mqnic;
    struct device *dev = &pdev->dev;

    int k = 0;

    dev_info(dev, "mqnic remove");

    if (!(mqnic = pci_get_drvdata(pdev))) {
        return;
    }

    misc_deregister(&mqnic->misc_dev);

    spin_lock(&mqnic_devices_lock);
    list_del(&mqnic->dev_list_node);
    spin_unlock(&mqnic_devices_lock);

    for (k = 0; k < MQNIC_MAX_IF; k++)
    {
        if (mqnic->ndev[k])
        {
            mqnic_destroy_netdev(mqnic->ndev[k]);
        }
    }

    mqnic_unregister_phc(mqnic);

    pci_clear_master(pdev);
    mqnic_remove_i2c(mqnic);
    pci_free_irq_vectors(pdev);
    pci_iounmap(pdev, mqnic->hw_addr);
    pci_release_regions(pdev);
    pci_disable_device(pdev);
}

static void mqnic_shutdown(struct pci_dev *pdev)
{
    struct mqnic_dev *mqnic = pci_get_drvdata(pdev);
    struct device *dev = &pdev->dev;

    dev_info(dev, "mqnic shutdown");

    if (!mqnic) {
        return;
    }

    // ensure DMA is disabled on shutdown
    pci_clear_master(pdev);
}

static struct pci_driver pci_driver = {
    .name = DRIVER_NAME,
    .id_table = pci_ids,
    .probe = mqnic_probe,
    .remove = mqnic_remove,
    .shutdown = mqnic_shutdown
};

static int __init mqnic_init(void)
{
    return pci_register_driver(&pci_driver);
}

static void __exit mqnic_exit(void)
{
    pci_unregister_driver(&pci_driver);
}

module_init(mqnic_init);
module_exit(mqnic_exit);
